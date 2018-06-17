# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import db_sqlite
import smtp
import strutils

import ../database/database

var db = conn()

var smtpAddress    = ""
var smtpPort       = ""
var smtpFrom       = ""
var smtpUser       = ""
var smtpPassword   = ""


proc sendMailNow*(subject, message, recipient: string) {.async.} =
  ## Send the email through smtp

  when defined(dev):
    echo "Dev: Mail start"

  #when defined(dev) and not defined(devemailon):
  #  echo "Dev is true, email is not send"
  #  return
  const otherHeaders = @[("Content-Type", "text/html; charset=\"UTF-8\"")]  
  
  echo "mail1"
  var client = newAsyncSmtp(useSsl = true, debug = false)
  echo "mail2"
  echo smtpUser
  echo smtpPassword
  echo smtpPort
  await client.connect(smtpAddress, Port(parseInt(smtpPort)))
  echo "mail3"
  
  await client.auth(smtpUser, smtpPassword)
  
  let from_addr = smtpFrom
  let toList = @[recipient]

  var headers = otherHeaders
  headers.add(("From", from_addr))

  let encoded = createMessage(subject, message, toList, @[], headers)

  try:
    echo "sin"
    await client.sendMail(from_addr, toList, $encoded)

  except:
    echo "Error in sending mail: " & recipient

  when defined(dev):
    echo "Email send"


proc sendMailDb*(db: DbConn, mailID: string) {.async.} =
  ## Get data from mail template and send
  ## Uses Sync Socket

  let mail = getRow(db, sql"SELECT recipient, subject, body FROM mail_templates WHERE id = ?", mailID)
  #asyncCheck sendMailNow(mail[1], mail[2], mail[0])

  let recipient = mail[0]
  let subject   = mail[1]
  let message   = mail[2]

  when defined(dev):
    echo "Dev: Mail start"

  const otherHeaders = @[("Content-Type", "text/html; charset=\"UTF-8\"")]  
  
  var client = newSmtp(useSsl = true, debug = false)
  client.connect(smtpAddress, Port(parseInt(smtpPort)))
  client.auth(smtpUser, smtpPassword)
  
  let from_addr = smtpFrom
  let toList = @[recipient]

  var headers = otherHeaders
  headers.add(("From", from_addr))

  let encoded = createMessage(subject, message, toList, @[], headers)

  try:
    client.sendMail(from_addr, toList, $encoded)

  except:
    echo "Error in sending mail: " & recipient

  when defined(dev):
    echo "Email send"



proc mailUpdateParameters*(db: DbConn) =
  ## Update mail settings in variables

  let mailSettings = getRow(db, sql"SELECT address, port, fromaddress, user, password FROM mail_settings WHERE id = ?", "1")

  smtpAddress    = mailSettings[0]
  smtpPort       = mailSettings[1]
  smtpFrom       = mailSettings[2]
  smtpUser       = mailSettings[3]
  smtpPassword   = mailSettings[4]


proc mailDatabase*(db: DbConn) =
  ## Creates mail tables in database

  # Mail settings
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS mail_settings (
    id INTEGER PRIMARY KEY,
    address TEXT,
    port TEXT,
    fromaddress TEXT,
    user TEXT,
    password TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
  if getAllRows(db, sql"SELECT id FROM mail_settings").len() <= 0:
    exec(db, sql"INSERT INTO mail_settings (address, port, fromaddress, user, password) VALUES (?, ?, ?, ?, ?)", "smtp.com", "537", "mail@mail.com", "mailer", "secret")

  # Mail templates
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS mail_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    recipient TEXT,
    subject TEXT,
    body TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")


mailDatabase(db)
mailUpdateParameters(db)