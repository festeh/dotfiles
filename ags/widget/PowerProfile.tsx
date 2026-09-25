import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk4"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

const PROFILE_PATH = "/sys/firmware/acpi/platform_profile"
const PROFILE_CHOICES_PATH = "/sys/firmware/acpi/platform_profile_choices"
const PROFILE_HELPER = "/usr/local/libexec/ags-set-power-profile"

const PROFILE_SPECS = [
  {
    value: "low-power",
    label: "Low power",
    icon: "power-profile-power-saver-symbolic",
  },
  {
    value: "quiet",
    label: "Quiet",
    icon: "audio-volume-muted-symbolic",
  },
  {
    value: "balanced",
    label: "Balanced",
    icon: "power-profile-balanced-symbolic",
  },
  {
    value: "performance",
    label: "Performance",
    icon: "power-profile-performance-symbolic",
  },
] as const

type ProfileName = typeof PROFILE_SPECS[number]["value"]

function readFile(path: string): string {
  try {
    const [ok, contents] = GLib.file_get_contents(path)
    return ok ? new TextDecoder().decode(contents).trim() : ""
  } catch {
    return ""
  }
}

function isProfileName(value: string): value is ProfileName {
  return PROFILE_SPECS.some(profile => profile.value === value)
}

function readCurrentProfile(): ProfileName | "" {
  const profile = readFile(PROFILE_PATH)
  return isProfileName(profile) ? profile : ""
}

const supportedProfiles = new Set(readFile(PROFILE_CHOICES_PATH).split(/\s+/))
const availableProfiles = PROFILE_SPECS.filter(profile => supportedProfiles.has(profile.value))
const activeProfile = Variable<ProfileName | "">(readCurrentProfile()).poll(
  2_000,
  current => readCurrentProfile() || current,
)
const pendingProfile = Variable<ProfileName | "">("")
const profileError = Variable("")

function profileLabel(profile: ProfileName | ""): string {
  return PROFILE_SPECS.find(spec => spec.value === profile)?.label ?? "Unavailable"
}

function finishProfileChange(profile: ProfileName, process: Gio.Subprocess, result: Gio.AsyncResult) {
  try {
    const [, , stderr] = process.communicate_utf8_finish(result)
    if (!process.get_successful()) {
      const cancelled = process.get_exit_status() === 126 || stderr?.toLowerCase().includes("dismissed")
      profileError.set(cancelled ? "Authorization cancelled" : "Could not change power mode")
      return
    }

    activeProfile.set(readCurrentProfile() || profile)
  } catch (error) {
    console.error("power-profile: failed to change profile:", error)
    profileError.set("Could not change power mode")
  } finally {
    pendingProfile.set("")
  }
}

function setProfile(profile: ProfileName) {
  if (pendingProfile.get() !== "" || profile === activeProfile.get()) return

  pendingProfile.set(profile)
  profileError.set("")

  try {
    const process = Gio.Subprocess.new(
      ["/usr/bin/pkexec", "--disable-internal-agent", PROFILE_HELPER, profile],
      Gio.SubprocessFlags.STDOUT_PIPE |
        Gio.SubprocessFlags.STDERR_PIPE,
    )
    process.communicate_utf8_async(null, null, (_proc, result) => {
      finishProfileChange(profile, process, result)
    })
  } catch (error) {
    console.error("power-profile: failed to start pkexec:", error)
    pendingProfile.set("")
    profileError.set("Could not request authorization")
  }
}

function ProfileButton({ profile }: { profile: typeof PROFILE_SPECS[number] }) {
  return (
    <button
      focusable={false}
      hexpand={true}
      sensitive={bind(pendingProfile).as(pending => pending === "")}
      tooltipText={profile.label}
      cssClasses={Variable.derive(
        [activeProfile, pendingProfile],
        (active, pending) => {
          const classes = ["power-profile-option"]
          if (active === profile.value) classes.push("active")
          if (pending === profile.value) classes.push("pending")
          return classes
        },
      )()}
      onClicked={() => setProfile(profile.value)}
    >
      <box spacing={7}>
        <image iconName={profile.icon} css="font-size: 16px" />
        <label label={profile.label} />
      </box>
    </button>
  )
}

export default function PowerProfile() {
  const firstRow = availableProfiles.slice(0, 2)
  const secondRow = availableProfiles.slice(2)

  return (
    <box
      visible={availableProfiles.length > 0}
      cssClasses={bind(profileError).as(error =>
        error ? ["power-profile-widget", "error"] : ["power-profile-widget"]
      )}
      spacing={7}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <box cssClasses={["power-profile-header"]} spacing={8}>
        <image iconName="power-profile-balanced-symbolic" css="font-size: 18px" />
        <label label="Power mode" xalign={0} hexpand={true} />
        <image
          visible={bind(pendingProfile).as(pending => pending !== "")}
          iconName="emblem-synchronizing-symbolic"
          cssClasses={["power-profile-spinner"]}
        />
        <label
          cssClasses={["power-profile-current"]}
          label={bind(activeProfile).as(profileLabel)}
        />
      </box>

      <box homogeneous={true} spacing={5}>
        {firstRow.map(profile => <ProfileButton profile={profile} />)}
      </box>

      <box visible={secondRow.length > 0} homogeneous={true} spacing={5}>
        {secondRow.map(profile => <ProfileButton profile={profile} />)}
      </box>

      <label
        visible={bind(profileError).as(error => error !== "")}
        cssClasses={["power-profile-error"]}
        label={bind(profileError)}
        xalign={0}
      />
    </box>
  )
}
