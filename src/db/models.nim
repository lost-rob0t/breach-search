import times
import options
import sequtils
import db_sqlite
import os
# TODO Try this https://gulpf.github.io/tiny_sqlite/tiny_sqlite.html
#
let EMAIL_INSERT = sql"INSERT INTO EMAIL(eUsername, eDomain, password, username) VALUES(?,?,?,?)"
type
  Email* = object
    eUsername* : string
    username*: string
    eDomain*: string
    password*: string

  KeyboardInterrupt = object of CatchableError

proc handler() {.noconv.} =
  raise newException(KeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)

template commit*(db: DbConn) =
  db.exec(sql"COMMIT")


proc initDb*(db: DbConn) =
  let emailsTable = sql"""
  CREATE TABLE IF NOT EXISTS "Email" (
  "eUsername"	TEXT,
  "eDomain"	TEXT,
  "password"	TEXT,
  "username"	TEXT,
  UNIQUE("eUsername","eDomain","password")
  );"""

  let pragma = sql"""
  PRAGMA journal_mode = WAL;
  PRAGMA temp_store = MEMORY;
  PRGAMA synchronous = NORMAL;
  """
  db.exec(pragma)
  db.exec(emailsTable)

proc createIndex*(db: DbConn) =
  let emailIndex = sql"""
  CREATE INDEX IF NOT EXISTS "emailIndex" ON "Email" (
  "eDomain"	ASC,
  "eUsername"	ASC,
  "password",
  "username"
  );
  """
  db.exec(emailIndex)

proc insertEmail*(db: DbConn, email: Email, insertSmt: SqlPrepared) =
  db.exec(insertSmt, email.eUsername, email.eDomain, email.password, email.username)

proc getEmail*(db: DbConn, email: Email): seq[Email] =
  var r: seq[Email]
  for e in db.fastRows(sql"SELECT eUsername, eDomain, password, username FROM Email WHERE eUsername = ? AND eDomain = ?;", email.eUsername, email.eDomain):
    let email = Email(eUsername: e[0], eDomain: e[1], password: e[2], username: e[3])
    r.add(email)
  result = r


proc getDomain*(db: DbConn, domain: string): seq[Email] =
  var r: seq[Email]
  for e in db.fastRows(sql"SELECT eUsername, eDomain, password, username FROM Email WHERE eDomain = ?;"):
    let email = Email(eUsername: e[0], eDomain: e[1], password: e[2], username: e[3])
    r.add(email)
  result = r
proc getUsername*(db: DbConn, username: string): seq[Email] =
  var r: seq[Email]
  for e in db.fastRows(sql"SELECT eUsername, eDomain, password, username FROM Email WHERE eUsername = ? OR WHERE username = ?;", username):
    let email = Email(eUsername: e[0], eDomain: e[1], password: e[2], username: e[3])
    r.add(email)
  result = r

template bulkInsert*(db: DbConn, emails: untyped) =
  try:
    for email in emails:
      db.insertEmail(email, EMAIL_INSERT)
    db.commit()
  except DbError:
    when defined(debug):
      echo(getCurrentExceptionMsg())
