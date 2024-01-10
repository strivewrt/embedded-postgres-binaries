package test

import (
	"archive/tar"
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"path"
	"strings"
	"testing"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/require"
)

const (
	registry   = "docker.io"
	repository = "strivewrt/embedded-postgres-binaries"
	tag        = "alpine-12.15.0-1e29bb60614490b076fb6621228c3131"
)

func TestPullFile(t *testing.T) {
	ref, err := name.ParseReference(registry + "/" + repository + ":" + tag)
	require.NoError(t, err)
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain))
	require.NoError(t, err)
	layers, err := img.Layers()
	require.NoError(t, err)
	require.NotNil(t, layers)
	uc, err := layers[len(layers)-1].Uncompressed()
	require.NoError(t, err)
	f, err := tar.NewReader(uc).Next()
	require.NoError(t, err)
	require.NotNil(t, f)
	require.True(t, strings.HasSuffix(f.Name, ".jar"))
}

func randomPort(t *testing.T) uint32 {
	t.Helper()
	conn, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	return uint32(conn.Addr().(*net.TCPAddr).Port)
}

func TestEmbeddedPostgres(t *testing.T) {
	for _, version := range []embeddedpostgres.PostgresVersion{
		embeddedpostgres.V15,
		embeddedpostgres.V14,
		embeddedpostgres.V13,
		embeddedpostgres.V12,
	} {
		t.Run(fmt.Sprintf("is compatible with version %s", version), func(t *testing.T) {
			tmp, err := os.MkdirTemp(os.TempDir(), string(version))
			if err != nil {
				t.Fatal(err)
			}

			cfg := embeddedpostgres.DefaultConfig().
				BinaryRepositoryURL("http://maven/").
				Version(version).
				Database("postgres").
				Username("postgres").
				Password("postgres").
				Port(randomPort(t)).
				RuntimePath(tmp).
				DataPath(path.Join(tmp, "data")).
				Logger(io.Discard)
			postgres := embeddedpostgres.NewDatabase(cfg)
			if err := postgres.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() {
				if err := postgres.Stop(); err != nil {
					t.Fatal(err)
				}
			}()

			conn, err := pgx.Connect(context.Background(), cfg.GetConnectionURL())
			if err != nil {
				t.Fatal(err)
			}
			defer func() {
				if err := conn.Close(context.Background()); err != nil {
					t.Fatal(err)
				}
			}()

			var serverVersion string
			if err := conn.QueryRow(context.Background(), "SHOW SERVER_VERSION").Scan(&serverVersion); err != nil {
				t.Fatal(err)
			}
			if serverVersion != string(version) && fmt.Sprintf("%s.0", serverVersion) != string(version) {
				t.Fatalf("expected version %q, got %q", version, serverVersion)
			}

			if _, err := conn.Exec(context.Background(), "CREATE EXTENSION postgis"); err != nil {
				t.Fatal(err)
			}
			expected := os.Getenv("POSTGIS_VERSION")
			var actual string
			if err := conn.QueryRow(context.Background(), "SELECT PostGIS_Lib_Version()").Scan(&actual); err != nil {
				t.Fatal(err)
			}
			if actual != expected {
				t.Fatalf("expected %q, got %q", expected, actual)
			}
		})
	}
}
