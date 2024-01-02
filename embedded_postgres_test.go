package test

import (
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"path"
	"testing"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
	"github.com/jackc/pgx/v5"
)

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
