use crate::types::Package;
use rusqlite::{params, Connection};
use std::cell::RefCell;
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DbError {
    #[error("SQLite error: {0}")]
    SqliteError(#[from] rusqlite::Error),
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

/// Combined database handle for all repomd `SQLite` tables.
///
/// All data is staged in an in-memory SQLite database and flushed to disk
/// at [`finish`](Self::finish) time via `VACUUM INTO`.
pub struct RepomdDb {
    conn: RefCell<Connection>,
    target: PathBuf,
}

impl RepomdDb {
    pub fn new(path: &Path) -> Result<Self, DbError> {
        let conn = Connection::open_in_memory()?;
        conn.execute_batch(
            "PRAGMA synchronous = OFF;
             PRAGMA journal_mode = OFF;
             PRAGMA cache_size = 10000;
             PRAGMA temp_store = MEMORY;

             CREATE TABLE IF NOT EXISTS \"primary\" (
                 pkgKey INTEGER PRIMARY KEY,
                 pkgId TEXT NOT NULL,
                 name TEXT NOT NULL,
                 arch TEXT,
                 version TEXT,
                 epoch INTEGER,
                 release TEXT,
                 summary TEXT,
                 description TEXT,
                 url TEXT,
                 license TEXT,
                 time_file INTEGER,
                 time_build INTEGER,
                 rpm_license TEXT,
                 rpm_vendor TEXT,
                 rpm_group TEXT,
                 rpm_buildhost TEXT,
                 rpm_sourcerpm TEXT,
                 rpm_header_start INTEGER,
                 rpm_header_end INTEGER,
                 rpm_packager TEXT,
                 size_archive INTEGER,
                 size_installed INTEGER,
                 size_package INTEGER,
                 location_href TEXT,
                 location_base TEXT,
                 checksum TEXT,
                 checksum_type TEXT
             );

             CREATE TABLE IF NOT EXISTS \"filelist\" (
                 id INTEGER PRIMARY KEY AUTOINCREMENT,
                 pkgKey INTEGER NOT NULL,
                 pkgId TEXT NOT NULL,
                 name TEXT NOT NULL,
                 arch TEXT,
                 version TEXT,
                 epoch INTEGER,
                 release TEXT,
                 filename TEXT NOT NULL,
                 type TEXT
             );
             CREATE INDEX IF NOT EXISTS filelist_idx ON filelist(pkgId);

             CREATE TABLE IF NOT EXISTS \"other\" (
                 id INTEGER PRIMARY KEY AUTOINCREMENT,
                 pkgKey INTEGER NOT NULL,
                 pkgId TEXT NOT NULL,
                 name TEXT NOT NULL,
                 arch TEXT,
                 version TEXT,
                 epoch INTEGER,
                 release TEXT,
                 filename TEXT NOT NULL
             );
             CREATE INDEX IF NOT EXISTS other_idx ON other(pkgId);",
        )?;
        Ok(Self {
            conn: RefCell::new(conn),
            target: path.to_path_buf(),
        })
    }

    /// Insert a package into all three database tables in a single transaction.
    /// Returns the pkgKey on success.
    pub fn insert_package(&self, pkg: &Package) -> Result<i64, DbError> {
        let mut conn = self.conn.borrow_mut();
        let tx = conn.transaction()?;

        tx.execute(
            "INSERT INTO \"primary\" (pkgId, name, arch, version, epoch, release,
                summary, description, url, license, time_file, time_build,
                rpm_license, rpm_vendor, rpm_group, rpm_buildhost, rpm_sourcerpm,
                rpm_header_start, rpm_header_end, rpm_packager, size_archive,
                size_installed, size_package, location_href, location_base,
                checksum, checksum_type)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
                    ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26, ?27)",
            params![
                pkg.pkgid,
                pkg.name,
                pkg.arch,
                pkg.version,
                pkg.epoch,
                pkg.release,
                pkg.summary,
                pkg.description,
                pkg.url,
                pkg.license,
                pkg.time_file,
                pkg.time_build,
                pkg.license,
                pkg.vendor,
                "",
                pkg.buildhost,
                pkg.sourcerpm,
                pkg.header_start,
                pkg.header_end,
                pkg.vendor,
                pkg.size_archive,
                pkg.size_installed,
                pkg.size_package,
                pkg.location_href,
                "",
                pkg.checksum,
                "sha256",
            ],
        )?;
        let pkg_key = tx.last_insert_rowid();

        for file in &pkg.files {
            tx.execute(
                "INSERT INTO \"filelist\" (pkgKey, pkgId, name, arch, version, epoch,
                    release, filename, type)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                params![
                    pkg_key,
                    pkg.pkgid,
                    pkg.name,
                    pkg.arch,
                    pkg.version,
                    pkg.epoch,
                    pkg.release,
                    file.path,
                    file.file_type,
                ],
            )?;
        }

        tx.execute(
            "INSERT INTO \"other\" (pkgKey, pkgId, name, arch, version, epoch, release, filename)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                pkg_key,
                pkg.pkgid,
                pkg.name,
                pkg.arch,
                pkg.version,
                pkg.epoch,
                pkg.release,
                pkg.location_href,
            ],
        )?;

        tx.commit()?;
        Ok(pkg_key)
    }

    /// Flush the in-memory database to disk.
    pub fn finish(self) -> Result<(), DbError> {
        let conn = self.conn.into_inner();
        conn.execute_batch("ANALYZE;")?;
        let target = self.target.to_str().unwrap_or("repomd.sqlite");
        conn.execute("VACUUM INTO ?1", params![target])?;
        Ok(())
    }
}

/// Insert a package into all repomd `SQLite` tables.
///
/// Note: For bulk inserts, use [`RepomdDb`] directly for better performance.
pub fn db_insert_packages(db_path: &Path, packages: &[Package]) -> Result<(), DbError> {
    let db = RepomdDb::new(db_path)?;
    for pkg in packages {
        if let Err(e) = db.insert_package(pkg) {
            eprintln!("Warning: Failed to insert package {}: {}", pkg.name, e);
        }
    }
    db.finish()?;
    Ok(())
}

/// Initialize the in-memory database. Returns a handle ready for insertion.
pub fn db_init(path: &Path) -> Result<RepomdDb, DbError> {
    RepomdDb::new(path)
}

/// Flush and close the database.
pub fn db_fini(db: RepomdDb) -> Result<(), DbError> {
    db.finish()
}
