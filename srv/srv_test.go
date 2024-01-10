package srv

import (
	"archive/tar"
	"compress/gzip"
	"io"
	"net/http"
	"net/http/httptest"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	registry   = "docker.io"
	repository = "strivewrt/embedded-postgres-binaries"
	tag        = "latest"
)

type response struct {
	code    int
	headers http.Header
}

func (r *response) Header() http.Header {
	return r.headers
}

func (r *response) Write(bytes []byte) (int, error) {
	return io.Discard.Write(bytes)
}

func (r *response) WriteHeader(statusCode int) {
	r.code = statusCode
}

func newResponse() *response {
	return &response{
		code:    http.StatusOK,
		headers: make(http.Header),
	}
}

func TestBinaryServer(t *testing.T) {
	paths := make([]string, 0)
	img, err := ResolveImage(registry + "/" + repository + ":" + tag)
	require.NoError(t, err)
	layers, err := img.Layers()
	require.NoError(t, err)
	for _, layer := range layers {
		c, err := layer.Compressed()
		require.NoError(t, err)
		gz, err := gzip.NewReader(c)
		require.NoError(t, err)
		tarReader := tar.NewReader(gz)
		for {
			f, err := tarReader.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err)
			if path.Ext(f.Name) == ".jar" {
				paths = append(paths, path.Clean(path.Join("/", f.Name)))
			}
		}
	}
	require.NotEmpty(t, paths)

	srv, err := BinaryServer(img)
	require.NoError(t, err)
	defer srv.Close()

	for _, p := range paths {
		url := srv.URL + p
		req := httptest.NewRequest(http.MethodGet, url, nil)
		w := newResponse()
		srv.Config.Handler.ServeHTTP(w, req)
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, w.code, url)
		assert.Equal(t, "application/java-archive", w.headers.Get("content-type"), url)
	}
}
