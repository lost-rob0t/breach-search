import times
import options
import sequtils
import db_sqlite
import sqlite3
import parsecsv
import json
import strutils, strformat
#import os
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
  db.exec(sql"COMMIT;")
template transaction*(db: DbConn) =
  db.exec(sql"BEGIN;")

template rollback*(db: DbConn) =
  db.exec(sql"ROLLBACK")

template optimize*(db: DbConn) =
  db.exec(sql"pragma optimize;")
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
  pragma journal_mode = WAL;
  pragma synchronous = normal;
  pragma temp_store = memory;
  pragma mmap_size = 30000000000;
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


type
  Config* = ref object
    # TODO give this the option to give dir or file.
    filePath*: string
    mode*: string
    emailField*: string
    usernameField*: string
    passwordField*: string
    #breachName*: string
    #breachDesc*: string
    #breachDate*: string
    dbPath*: string
    errorFile*: string
    imported*: bool
    sep*: string
    total*: int
  ParsedEmail* = object
    username*: string
    domain*: string

proc parseLine*(line: JsonNode, config: Config): Email =
  var
    emailUser, domain: string
    username, password: string

  let email = line{config.emailField}.getStr("").split("@")
  emailUser = email[0]
  domain = email[1]
  username = line{config.usernameField}.getStr("")
  password = line{config.passwordField}.getStr("")
  result = Email(eUsername: emailUser, eDomain: domain, username: username, password: password)


proc parseLine*(line: var CsvParser, config: Config): Email =
  var
    emailUser, domain: string
    username, password: string

  let email = line.rowEntry(config.emailField).split("@")
  emailUser = email[0]
  domain = email[1]
  username = line.rowEntry(config.usernameField)
  password = line.rowEntry(config.passwordField)

  result = Email(eUsername: emailUser, eDomain: domain, username: username, password: password)


proc parseLine*(line: string, config: Config): Email {.raises: [IndexDefect].} =
   var
    emailUser, domain: string
    username, password: string
   let splitLine = line.split(config.sep)
   let email = splitLine[0].split("@")
   emailUser = email[0]
   domain = email[1]
   password = splitLine[1]
   username = ""
   result = Email(eUsername: emailUser, eDomain: domain, username: username, password: password)

proc readConfig*(path: string): seq[Config] =
  var configs: seq[Config]
  let f = open(path, fmRead)
  defer: f.close()
  let jconfig = f.readAll.parseJson
  for config in jconfig.getElems:
    when defined(debug):
      echo $config
    let conf = config.to(Config)
    configs.add(conf)
  result = configs

proc writeConfig*(configs: seq[Config], path: string) =
  let f = open(path, fmWrite)
  defer: f.close()
  let j = %configs
  # BUG Not working why?
  f.write(pretty(j, indent=4))

proc insertEmail*(db: DbConn, email: Email, insertSmt: SqlQuery) =
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


template bulkInsert*(db: DbConn, emails: untyped, errorFile: File) =
  # TODO make this a try insert bulk
  try:
    db.transaction
    for email in emails:
      db.insertEmail(email, EMAIL_INSERT)
    db.commit()
  except DbError:
    db.rollback
    for email in emails:
      errorFile.writeLine(email.eUsername & "@" & email.eDomain & ":" & email.password)
when isMainModule:
  var db = open("test.db", "", "", "")
  db.initDb
