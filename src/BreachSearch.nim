import db
import parsecsv
import strutils
import suru
import db_sqlite
template updateBar(sb: untyped, amount: int) =
  for x in countup(0, amount):
    inc sb[0]

proc `$`(e: Email): string =
  if e.username != "":
    result = e.eUsername & "@" & e.eDomain & ":" & e.password
  else:
    result = e.eUsername & "@" & e.eDomain & "|" & e.username & ":" & e.password


proc parseCsvFile*(config: Config) =
  var
    db: DbConn
    p: CsvParser
    sb: SuruBar
    errorFile: File

  try:
    errorFile = open(config.errorFile, fmAppend)
    db = open(config.dbPath, "", "", "")
    db.initDb
    sb = initSuruBar()
    sb[0].total = config.total
    sb.setup()
    var i = 0
    var emails: seq[Email]
    p.open(config.filePath)
    p.readHeaderRow()
    while p.readRow:
      let e = p.parseLine(config)
      emails.add(e)
      i += 1
      if i == 1000:
        db.bulkInsert(emails, errorFile)
        sb.updateBar(emails.len)
        emails = @[]
        i = 0
    if emails.len != 0:
      db.bulkInsert(emails, errorFile)
      sb.updateBar(emails.len)
      emails = @[]

    echo "Creating index, this may take a WHILE...."
    db.createIndex
    echo "Optmizing database"
    db.optimize
  finally:
    db.close()
    p.close()
    errorFile.close()
    sb.finish()


proc parseJsonFile*(config: Config) =
  discard

proc parseCombo(config: Config) =
  var
    combo: File
    errorFile: File
    db: DbConn
    sb: SuruBar
  try:
    combo = open(config.filePath, fmRead)
    errorFile = open(config.errorFile, fmAppend)
    db = open(config.dbPath, "", "", "")
    db.initDb
    sb = initSuruBar()
    sb[0].total = config.total
    sb.setup()
    db.initDb
    var i = 0
    var emails: seq[Email]
    for line in combo.lines:
      try:
        let e = line.parseLine(config)
        emails.add(e)
        if i == 10000:
          db.bulkInsert(emails, errorFile)
          sb.updateBar(emails.len)
          emails = @[]
          i = 0
      except IndexDefect:
        when defined(debug):
          echo(getCurrentExceptionMsg())
        errorFile.write(line & "\n")
      finally:
        i += 1
    if emails.len != 0:
        db.bulkInsert(emails, errorFile)
        emails = @[]

    echo "Creating index, this may take a WHILE...."
    db.createIndex
    echo "Optmizing database"
    db.optimize
  finally:
    sb.finish()
    db.close()
    combo.close()

proc genConfig() =
  discard
proc doImport(config: string) =
  var configs = config.readConfig
  for config in configs:
    when defined(debug):
      config.imported = false
    if config.imported == true:
      continue
    when defined(mem):
      config.dbPath = ":memory:"
    case config.mode:
      of "csv":
        config.parseCsvFile
        config.imported = true
      of "json":
        config.parseJsonFile
        config.imported = true
      of "combo":
        config.parseCombo
        config.imported = true
      else:
        echo "Unsuported mode: " & config.mode
  configs.writeConfig(config)
proc main(config: string, email = "", username = "", domain = "", password = "") =
  config.doImport()
  let configs = config.readConfig()
  for config in configs:
    let db = open(config.dbPath, "", "", "")
    defer: db.close
    if email != "":
      try:
        let edata = email.split("@")
        var email = Email(eUsername: edata[0], eDomain: edata[1])
        let emails = db.getEmail(email)
        for x in emails:
          echo($x)
      except IndexDefect:
        echo("Enter a valid email")

when isMainModule:
  import cligen; dispatch(main)
