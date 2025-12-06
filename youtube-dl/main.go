package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type Video struct {
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	URL         string `json:"url"`
	Duration    int    `json:"duration,omitempty"`
	ViewCount   int64  `json:"view_count,omitempty"`
	LikeCount   int64  `json:"like_count,omitempty"`
}

type ChannelData struct {
	ChannelID   string  `json:"channel_id"`
	ChannelName string  `json:"channel_name"`
	ChannelURL  string  `json:"channel_url"`
	LastUpdated string  `json:"last_updated"`
	Videos      []Video `json:"videos"`
}

// ytdlpVideo represents the JSON output from yt-dlp
type ytdlpVideo struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	WebpageURL  string  `json:"webpage_url"`
	URL         string  `json:"url"`
	Duration    float64 `json:"duration"`
	UploadDate  string  `json:"upload_date"`
	ViewCount   int64   `json:"view_count"`
	LikeCount   int64   `json:"like_count"`
	// Channel info from playlist metadata
	PlaylistChannel   string `json:"playlist_channel"`
	PlaylistChannelID string `json:"playlist_channel_id"`
	PlaylistURL       string `json:"playlist_webpage_url"`
}

func expandPath(p string) (string, error) {
	if strings.HasPrefix(p, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(home, p[2:]), nil
	}
	return filepath.Abs(p)
}

func normalizeChannelInput(input string) string {
	input = strings.TrimSpace(input)

	// Already a full URL
	if strings.HasPrefix(input, "http://") || strings.HasPrefix(input, "https://") {
		// Ensure we're targeting the videos tab
		if !strings.HasSuffix(input, "/videos") && !strings.Contains(input, "/videos") {
			return strings.TrimSuffix(input, "/") + "/videos"
		}
		return input
	}

	// Handle @handle format
	if strings.HasPrefix(input, "@") {
		return fmt.Sprintf("https://www.youtube.com/%s/videos", input)
	}

	// Handle channel ID (starts with UC)
	if strings.HasPrefix(input, "UC") {
		return fmt.Sprintf("https://www.youtube.com/channel/%s/videos", input)
	}

	// Assume it's a handle without @
	return fmt.Sprintf("https://www.youtube.com/@%s/videos", input)
}

func loadExistingData(path string) (*ChannelData, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &ChannelData{Videos: []Video{}}, nil
		}
		return nil, fmt.Errorf("cannot read file: %w", err)
	}

	var channelData ChannelData
	if err := json.Unmarshal(data, &channelData); err != nil {
		return nil, fmt.Errorf("cannot parse JSON: %w", err)
	}

	return &channelData, nil
}

func saveData(path string, data *ChannelData) error {
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("cannot marshal JSON: %w", err)
	}

	// Write to temp file first, then rename for atomicity
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("cannot create directory: %w", err)
	}

	tmpFile := path + ".tmp"
	if err := os.WriteFile(tmpFile, jsonData, 0644); err != nil {
		return fmt.Errorf("cannot write temp file: %w", err)
	}

	if err := os.Rename(tmpFile, path); err != nil {
		os.Remove(tmpFile)
		return fmt.Errorf("cannot rename temp file: %w", err)
	}

	return nil
}

func fetchChannelVideos(channelURL string) ([]Video, string, string, string, error) {
	// Check if yt-dlp is installed
	if _, err := exec.LookPath("yt-dlp"); err != nil {
		return nil, "", "", "", fmt.Errorf("yt-dlp not found in PATH. Please install it: https://github.com/yt-dlp/yt-dlp")
	}

	cmd := exec.Command("yt-dlp",
		"--flat-playlist",
		"--dump-json",
		"--ignore-errors",
		"--no-warnings",
		channelURL,
	)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, "", "", "", fmt.Errorf("cannot create stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, "", "", "", fmt.Errorf("cannot start yt-dlp: %w", err)
	}

	var videos []Video
	var channelID, channelName, channelURLResult string
	scanner := bufio.NewScanner(stdout)

	// Increase scanner buffer for long descriptions
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		var ytVideo ytdlpVideo
		if err := json.Unmarshal([]byte(line), &ytVideo); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: cannot parse video entry: %v\n", err)
			continue
		}

		// Extract channel info from first video
		if channelID == "" && ytVideo.PlaylistChannelID != "" {
			channelID = ytVideo.PlaylistChannelID
			channelName = ytVideo.PlaylistChannel
			channelURLResult = ytVideo.PlaylistURL
		}

		videoURL := ytVideo.WebpageURL
		if videoURL == "" {
			videoURL = fmt.Sprintf("https://www.youtube.com/watch?v=%s", ytVideo.ID)
		}

		video := Video{
			Title:       ytVideo.Title,
			Description: ytVideo.Description,
			URL:         videoURL,
			Duration:    int(ytVideo.Duration),
			ViewCount:   ytVideo.ViewCount,
			LikeCount:   ytVideo.LikeCount,
		}
		videos = append(videos, video)
	}

	if err := scanner.Err(); err != nil {
		return nil, "", "", "", fmt.Errorf("error reading yt-dlp output: %w", err)
	}

	if err := cmd.Wait(); err != nil {
		// yt-dlp may return non-zero exit code even with some successful results
		if len(videos) == 0 {
			return nil, "", "", "", fmt.Errorf("yt-dlp failed: %w", err)
		}
	}

	return videos, channelID, channelName, channelURLResult, nil
}

func mergeVideos(existing, new []Video) ([]Video, int) {
	existingURLs := make(map[string]bool)
	for _, v := range existing {
		existingURLs[v.URL] = true
	}

	var merged []Video
	newCount := 0

	// Add new videos first
	for _, v := range new {
		if !existingURLs[v.URL] {
			merged = append(merged, v)
			newCount++
		}
	}

	// Then add existing videos
	merged = append(merged, existing...)

	return merged, newCount
}

func main() {
	var outputPath string
	flag.StringVar(&outputPath, "output", "", "Output file path (required)")
	flag.StringVar(&outputPath, "o", "", "Output file path (required)")
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Error: channel URL or handle is required")
		fmt.Fprintln(os.Stderr, "Usage: youtube-dl -o <output.json> <channel_url|@handle|channel_id>")
		os.Exit(1)
	}

	if outputPath == "" {
		fmt.Fprintln(os.Stderr, "Error: output path is required (-o flag)")
		fmt.Fprintln(os.Stderr, "Usage: youtube-dl -o <output.json> <channel_url|@handle|channel_id>")
		os.Exit(1)
	}

	channelInput := args[0]
	channelURL := normalizeChannelInput(channelInput)

	// Expand output path
	outputPath, err := expandPath(outputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot expand output path: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Fetching videos from %s...\n", channelURL)

	// Load existing data
	existingData, err := loadExistingData(outputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Fetch new videos
	newVideos, channelID, channelName, channelURLResult, err := fetchChannelVideos(channelURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Found %d videos from channel\n", len(newVideos))

	if len(existingData.Videos) > 0 {
		fmt.Printf("Loaded %d existing videos from %s\n", len(existingData.Videos), outputPath)
	}

	// Merge videos
	mergedVideos, addedCount := mergeVideos(existingData.Videos, newVideos)

	// Update channel data
	existingData.Videos = mergedVideos
	existingData.LastUpdated = time.Now().Format(time.RFC3339)

	if channelID != "" {
		existingData.ChannelID = channelID
	}
	if channelName != "" {
		existingData.ChannelName = channelName
	}
	if channelURLResult != "" {
		existingData.ChannelURL = channelURLResult
	}

	// Save data
	if err := saveData(outputPath, existingData); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Added %d new videos\n", addedCount)
	fmt.Printf("Total: %d videos\n", len(mergedVideos))
	fmt.Printf("Saved to %s\n", outputPath)
}
