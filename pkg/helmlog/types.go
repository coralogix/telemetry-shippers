package helmlog

// Changelog is the normalized changelog artifact structure.
type Changelog struct {
	Releases []Release `json:"releases" yaml:"releases"`
}

// Release is a single versioned changelog section.
type Release struct {
	Version string  `json:"version" yaml:"version"`
	Date    string  `json:"date" yaml:"date"`
	Entries []Entry `json:"entries" yaml:"entries"`
}

// Entry is a normalized changelog item.
type Entry struct {
	Tag  string `json:"tag" yaml:"tag"`
	Text string `json:"text" yaml:"text"`
}
