package rsync

import (
	"regexp"
	"strconv"
	"strings"
	"team-sync-web/internal/models"
)

// ParseProgress parses a line from rsync --progress output.
// Example: "  1,234,567  45%  12.34MB/s    0:01:23 (xfr#5, to-chk=10/20)"
var progressRe = regexp.MustCompile(
	`^\s*([\d,]+)\s+(\d+)%\s+(\S+/s)\s+(\S+)\s*(?:\(xfr#(\d+),\s*to-chk=(\d+)/(\d+)\))?`,
)

func ParseProgress(line string, transferID int64) *models.Progress {
	line = strings.TrimSpace(line)
	if line == "" {
		return nil
	}

	matches := progressRe.FindStringSubmatch(line)
	if matches == nil {
		return nil
	}

	bytesDone := parseCommaInt(matches[1])
	percent, _ := strconv.Atoi(matches[2])
	speed := matches[3]
	eta := matches[4]

	p := &models.Progress{
		TransferID: transferID,
		BytesDone:  bytesDone,
		Percent:    percent,
		Speed:      speed,
		ETA:        eta,
	}

	// xfr and to-chk info
	if matches[5] != "" && matches[7] != "" {
		filesDone, _ := strconv.ParseInt(matches[5], 10, 64)
		toCheck, _ := strconv.ParseInt(matches[6], 10, 64)
		total, _ := strconv.ParseInt(matches[7], 10, 64)
		p.FilesDone = filesDone
		p.FilesTotal = total
		_ = toCheck
	}

	// Estimate bytes_total from percent
	if percent > 0 {
		p.BytesTotal = bytesDone * 100 / int64(percent)
	}

	return p
}

func parseCommaInt(s string) int64 {
	s = strings.ReplaceAll(s, ",", "")
	v, _ := strconv.ParseInt(s, 10, 64)
	return v
}

// SplitCRLF splits rsync output on both \r and \n.
// rsync uses \r to update progress on the same line.
func SplitCRLF(data []byte, atEOF bool) (advance int, token []byte, err error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}

	// Find the earliest \r or \n
	for i := 0; i < len(data); i++ {
		if data[i] == '\r' || data[i] == '\n' {
			// Handle \r\n as a single separator
			advance := i + 1
			if data[i] == '\r' && i+1 < len(data) && data[i+1] == '\n' {
				advance = i + 2
			}
			return advance, data[:i], nil
		}
	}

	if atEOF {
		return len(data), data, nil
	}

	// Request more data
	return 0, nil, nil
}
