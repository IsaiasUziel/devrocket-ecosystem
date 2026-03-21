// Package devrocket exports the embedded configuration filesystem.
// The //go:embed directive must live in a file at the same directory
// level as the configs/ tree it embeds.
package devrocket

import "embed"

//go:embed all:configs
var Configs embed.FS
