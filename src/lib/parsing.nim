import parsecsv
import json
import ../db/models
import strutils

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
   if email[1].len < 3:
     raise newException(IndexDefect, "Email is invlaid!")
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
