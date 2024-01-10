package srv

import (
	"archive/tar"
	"compress/gzip"
	"io"
	"io/fs"
	"path"
	"testing"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/stretchr/testify/require"
)

var (
	ucf fs.FileInfo
	cf  fs.FileInfo
	// first jar in the layers, should involve the least seeking to retrieve
	needle = path.Join(
		"io",
		"zonky",
		"test",
		"postgres",
		"embedded-postgres-binaries-linux-amd64-alpine",
		"15.3.0",
		"embedded-postgres-binaries-linux-amd64-alpine-15.3.0.jar",
	)
)

func find(b *testing.B, t *tar.Reader) fs.FileInfo {
	b.Helper()
	for {
		f, err := t.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			b.Fatal(err)
		}
		if f.Name == needle {
			return f.FileInfo()
		}
	}
}

func BenchmarkBinaryServer(b *testing.B) {
	ref, err := name.ParseReference(registry + "/" + repository + ":" + tag)
	require.NoError(b, err)
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain))
	require.NoError(b, err)
	layers, err := img.Layers()
	require.NoError(b, err)
	if len(layers) == 0 {
		b.Fatalf("no layers found in img: %s", ref)
	}
	b.Run("Uncompressed", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			ucf = nil
			for _, layer := range layers {
				uc, err := layer.Uncompressed()
				require.NoError(b, err)
				t := tar.NewReader(uc)
				ucf = find(b, t)
				if ucf != nil {
					break
				}
			}
			require.NotNil(b, ucf)
		}
	})
	b.Run("Compressed", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			cf = nil
			for _, layer := range layers {
				c, err := layer.Compressed()
				require.NoError(b, err)
				gz, err := gzip.NewReader(c)
				require.NoError(b, err)
				t := tar.NewReader(gz)
				cf = find(b, t)
				if cf != nil {
					break
				}
			}
			require.NotNil(b, cf)
		}
	})
}
