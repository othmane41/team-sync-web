package rsync

import (
	"testing"
)

func TestParseProgress_BasicLine(t *testing.T) {
	line := "  1,234,567  45%  12.34MB/s    0:01:23"
	p := ParseProgress(line, 1)
	if p == nil {
		t.Fatal("expected progress, got nil")
	}
	if p.TransferID != 1 {
		t.Errorf("TransferID = %d, want 1", p.TransferID)
	}
	if p.BytesDone != 1234567 {
		t.Errorf("BytesDone = %d, want 1234567", p.BytesDone)
	}
	if p.Percent != 45 {
		t.Errorf("Percent = %d, want 45", p.Percent)
	}
	if p.Speed != "12.34MB/s" {
		t.Errorf("Speed = %q, want %q", p.Speed, "12.34MB/s")
	}
	if p.ETA != "0:01:23" {
		t.Errorf("ETA = %q, want %q", p.ETA, "0:01:23")
	}
	if p.BytesTotal != 2743482 { // 1234567 * 100 / 45
		t.Errorf("BytesTotal = %d, want 2743482", p.BytesTotal)
	}
}

func TestParseProgress_WithXfr(t *testing.T) {
	line := "  5,000,000  80%  25.00MB/s    0:00:05 (xfr#8, to-chk=2/15)"
	p := ParseProgress(line, 42)
	if p == nil {
		t.Fatal("expected progress, got nil")
	}
	if p.FilesDone != 8 {
		t.Errorf("FilesDone = %d, want 8", p.FilesDone)
	}
	if p.FilesTotal != 15 {
		t.Errorf("FilesTotal = %d, want 15", p.FilesTotal)
	}
	if p.Percent != 80 {
		t.Errorf("Percent = %d, want 80", p.Percent)
	}
}

func TestParseProgress_100Percent(t *testing.T) {
	line := "  10,000,000 100%  50.00MB/s    0:00:00 (xfr#20, to-chk=0/20)"
	p := ParseProgress(line, 5)
	if p == nil {
		t.Fatal("expected progress, got nil")
	}
	if p.Percent != 100 {
		t.Errorf("Percent = %d, want 100", p.Percent)
	}
	if p.BytesDone != 10000000 {
		t.Errorf("BytesDone = %d, want 10000000", p.BytesDone)
	}
	if p.FilesDone != 20 {
		t.Errorf("FilesDone = %d, want 20", p.FilesDone)
	}
	if p.FilesTotal != 20 {
		t.Errorf("FilesTotal = %d, want 20", p.FilesTotal)
	}
}

func TestParseProgress_EmptyLine(t *testing.T) {
	p := ParseProgress("", 1)
	if p != nil {
		t.Errorf("expected nil for empty line, got %+v", p)
	}
}

func TestParseProgress_NonProgressLine(t *testing.T) {
	p := ParseProgress("sending incremental file list", 1)
	if p != nil {
		t.Errorf("expected nil for non-progress line, got %+v", p)
	}
}

func TestParseProgress_ZeroPercent(t *testing.T) {
	line := "  0   0%    0.00kB/s    0:00:00"
	p := ParseProgress(line, 1)
	if p == nil {
		t.Fatal("expected progress, got nil")
	}
	if p.Percent != 0 {
		t.Errorf("Percent = %d, want 0", p.Percent)
	}
	if p.BytesTotal != 0 {
		t.Errorf("BytesTotal = %d, want 0 (no divide by zero)", p.BytesTotal)
	}
}

func TestSplitCRLF(t *testing.T) {
	tests := []struct {
		name   string
		input  string
		tokens []string
	}{
		{"newline", "a\nb\n", []string{"a", "b"}},
		{"carriage_return", "a\rb\r", []string{"a", "b"}},
		{"mixed", "a\rb\nc\r\nd", []string{"a", "b", "c", "d"}},
		{"empty_between", "a\r\rb", []string{"a", "", "b"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data := []byte(tt.input)
			var tokens []string
			for len(data) > 0 {
				advance, token, _ := SplitCRLF(data, false)
				if advance == 0 {
					// Remaining data, call with atEOF
					_, token, _ = SplitCRLF(data, true)
					if token != nil {
						tokens = append(tokens, string(token))
					}
					break
				}
				tokens = append(tokens, string(token))
				data = data[advance:]
			}
			if len(tokens) != len(tt.tokens) {
				t.Errorf("got %d tokens %v, want %d tokens %v", len(tokens), tokens, len(tt.tokens), tt.tokens)
				return
			}
			for i, tok := range tokens {
				if tok != tt.tokens[i] {
					t.Errorf("token[%d] = %q, want %q", i, tok, tt.tokens[i])
				}
			}
		})
	}
}
