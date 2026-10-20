#include "clock.hpp"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QThread>
#include <QTimeZone>
#include <QTimer>

#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <sys/timerfd.h>
#include <unistd.h>

static int clockFd = -1;
static bool cancelNextRead = false;

extern "C" ssize_t __real_read(int, void*, size_t);
extern "C" ssize_t __wrap_read(int fd, void* buffer, size_t length) {
    auto result = __real_read(fd, buffer, length);
    if (fd == clockFd && result > 0 && cancelNextRead) {
        cancelNextRead = false;
        errno = ECANCELED;
        return -1;
    }
    return result;
}

static void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

static void runFor(int milliseconds) {
    QEventLoop loop;
    QTimer::singleShot(milliseconds, &loop, &QEventLoop::quit);
    loop.exec();
}

static void requireFresh(const SystemClock& clock) {
    auto delta = clock.date().secsTo(QDateTime::currentDateTime());
    require(delta >= 0 && delta <= 1, "clock retained an overdue timestamp");
}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    try {
        // Preserve the second occurrence of the repeated hour at DST fall-back.
        auto repeated = QDateTime::fromString("2026-10-25T02:30:15+01:00", Qt::ISODate)
            .toTimeZone(QTimeZone("Europe/Berlin"));
        auto aligned = SystemClock::atPrecision(repeated, SystemClock::Minutes);
        require(repeated.secsTo(aligned) == -15 && aligned.offsetFromUtc() == 3600,
            "minute rounding jumped into the first DST hour");
        require(repeated.secsTo(aligned.addSecs(60)) == 45, "next minute deadline is in the past");
        require(repeated.secsTo(SystemClock::atPrecision(repeated, SystemClock::Hours)) == -1815,
            "hour rounding changed the DST occurrence");
        auto spring = QDateTime::fromString("2026-03-29T01:59:45+01:00", Qt::ISODate)
            .toTimeZone(QTimeZone("Europe/Berlin"));
        auto springNext = SystemClock::atPrecision(spring, SystemClock::Minutes).addSecs(60);
        require(spring.secsTo(springNext) == 15 && springNext.time().hour() == 3,
            "next minute did not cross spring DST correctly");

        SystemClock clock;
        clock.setPrecision(SystemClock::Minutes);
        int updates = 0;
        QObject::connect(&clock, &SystemClock::dateChanged, [&updates]() { ++updates; });

        for (const auto& entry : QDir("/proc/self/fdinfo").entryList(QDir::Files)) {
            QFile info("/proc/self/fdinfo/" + entry);
            if (info.open(QFile::ReadOnly) && info.readAll().contains("clockid: 0\n"))
                clockFd = entry.toInt();
        }
        require(clockFd >= 0, "no CLOCK_REALTIME timerfd was created");
        itimerspec timer {};
        require(timerfd_gettime(clockFd, &timer) == 0, "could not read wall-clock timer");
        require(timer.it_interval.tv_sec == 0 && timer.it_interval.tv_nsec == 0, "timer must be one-shot");
        require(timer.it_value.tv_sec >= 0 && timer.it_value.tv_sec <= 60, "minute deadline is misaligned");
        require(clock.seconds() == 0, "minute clock includes seconds");

        // An interrupted event loop must catch up in one delivery, then realign.
        clock.setPrecision(SystemClock::Seconds);
        QThread::msleep(2200);
        QCoreApplication::processEvents();
        requireFresh(clock);

        clock.setEnabled(false);
        timerfd_gettime(clockFd, &timer);
        require(timer.it_value.tv_sec == 0 && timer.it_value.tv_nsec == 0, "disabled clock is still armed");
        auto before = updates;
        runFor(1100);
        require(updates == before, "disabled clock continued updating");

        clock.setEnabled(true);
        clock.setPrecision(SystemClock::Minutes);
        require(clock.seconds() == 0, "re-enabled minute clock has seconds");

        // Exercise kernel cancellation handling without changing the host clock.
        cancelNextRead = true;
        itimerspec immediate {};
        clock_gettime(CLOCK_REALTIME, &immediate.it_value);
        immediate.it_value.tv_nsec += 1000000;
        if (immediate.it_value.tv_nsec >= 1000000000) {
            ++immediate.it_value.tv_sec;
            immediate.it_value.tv_nsec -= 1000000000;
        }
        before = updates;
        require(timerfd_settime(clockFd, TFD_TIMER_ABSTIME, &immediate, nullptr) == 0, "could not arm test deadline");
        runFor(25);
        require(!cancelNextRead && updates > before, "clock did not refresh after cancellation");
        timerfd_gettime(clockFd, &timer);
        require(timer.it_value.tv_sec <= 60, "cancelled clock did not rearm");

        std::cout << "Clock checks passed: wall-clock timer, DST alignment, catch-up, disable/re-enable, cancellation.\n";
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
