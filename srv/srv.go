package srv

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path"
	"sync"

	"github.com/docker/docker/client"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/daemon"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

func tryPodman(ref name.Reference) (v1.Image, error) {
	return tarball.Image(func() (stdout io.ReadCloser, err error) {
		c := exec.Command("podman", "image", "save", ref.String())
		if stdout, err = c.StdoutPipe(); err != nil {
			return
		}
		if err = c.Start(); err != nil {
			return
		}
		return
	}, nil)
}

func tryDocker(ref name.Reference) (v1.Image, error) {
	dc, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		return nil, err
	}
	return daemon.Image(ref, daemon.WithClient(dc))
}

var mu = sync.RWMutex{}

func tryRemote(ref name.Reference) (v1.Image, error) {
	cachePath := os.Getenv("XDG_CACHE_HOME")
	if cachePath == "" {
		cachePath = path.Join(os.Getenv("HOME"), ".cache", "embedded-postgres-binaries")
	}
	sha := sha256.New()
	uri := ref.String()
	sha.Write([]byte(uri))
	file := path.Join(cachePath, hex.EncodeToString(sha.Sum(nil))+".img")
	mu.RLock()
	if img, err := tarball.ImageFromPath(file, nil); err == nil {
		mu.RUnlock()
		return img, nil
	}
	mu.RUnlock()
	mu.Lock()
	defer mu.Unlock()
	// someone else may have populated the cache while we were waiting for the write lock
	if img, err := tarball.ImageFromPath(file, nil); err == nil {
		return img, nil
	}
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain))
	if err != nil {
		return nil, err
	}
	if err := tarball.WriteToFile(file, ref, img); err != nil {
		// We have fetched a valid image at this point, failure here indicates a problem with the cache
		// which we will re-attempt to populate on the next run. Right call seems to be to return the
		// image we have and allow the request to proceed.
		_ = err
	}
	return img, nil
}

// ResolveImage returns a v1.Image from the given uri.
// Sources are attempted in this order:
// 1. docker image cache
// 2. podman image cache
// 3. direct pull from remote registry
func ResolveImage(uri string) (img v1.Image, err error) {
	ref, err := name.ParseReference(uri)
	if err != nil {
		return
	}
	// in descending order by performance
	for _, f := range []func(name.Reference) (v1.Image, error){
		tryDocker,
		tryPodman,
		tryRemote,
	} {
		img, err = f(ref)
		if err == nil {
			return
		}
	}
	return
}

// BinaryServer returns a httptest.Server that serves compiled jars in maven format from the given image.
func BinaryServer(img v1.Image) (*httptest.Server, error) {
	layers, err := img.Layers()
	if err != nil {
		return nil, err
	}
	if len(layers) == 0 {
		return nil, errors.New("no layers found in image")
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		for _, layer := range layers {
			c, err := layer.Compressed()
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			gz, err := gzip.NewReader(c)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			t := tar.NewReader(gz)
			for {
				f, err := t.Next()
				if err != nil {
					if err == io.EOF {
						break
					} else {
						http.Error(w, err.Error(), http.StatusInternalServerError)
					}
					return
				}
				abs := "/" + f.Name
				if abs == r.URL.Path || abs == path.Join(r.URL.Path, "index.html") {
					mime := "application/java-archive"
					if path.Ext(f.Name) == ".html" {
						mime = "text/html"
					}
					for k, v := range map[string]string{
						"type":        mime,
						"length":      fmt.Sprint(f.Size),
						"disposition": "attachment; filename=" + path.Base(f.Name),
					} {
						w.Header().Set("content-"+k, v)
					}
					if _, err := io.Copy(w, t); err != nil {
						http.Error(w, err.Error(), http.StatusInternalServerError)
					}
					return
				}
			}
		}
		http.NotFound(w, r)
	})), nil
}
