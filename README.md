QNETNINFO
=========

`qnetinfo.sh` is a simple POSIX compatible shell script that queries network information from Quectel **EM12**, **EG12** or **EG18** LTE modem, extracts and displays it in human readable form.  Besides a few of typical shell utilities, only requires `microcom` to be present, so common routers utilizing Busybox should be fine.

# Installing

Copy `qnetinfo.sh` to target router.  For development purposes a small HTTP server, `qnetinfo-http-server.sh`, is included.  The HTTP server implementation requires a modern Bash (if modern is a word that can be associated with any POSIX based shell language).

# Running

Execute `qnetinfo.sh`.  No command line arguments are parsed but the default parameter values can be re-defined using the following environment variables.  Ideally, you should not need to touch these.

* `LOGLEVEL`: The larger the positive integer, the more verbose the output is.
* `TTYMODEM`: Modem TTY path (e.g. `/dev/ttyUSBn`).
* `TTYAWAIT`: Modem TTY I/O timeout, in milliseconds.
* `TTYSPEED`: Modem TTY baudrate.
* `INTERVAL`: Time, in seconds, between complete queries.
* `AWOLTIME`: Time, in seconds, after which a cell is considered lost (but not forgotten).  If zero, never considered lost.
* `OUTATIME`: Time, in seconds, after which a cell is discarded.  Ditto.
* `PARALLEL`: Number of parallel renderers.
* `ANYMODEM`: Do not require the specified modem models, however, the vendor must match (as no standard AT queries are used).
* `MICROCOM`: `microcom` location.
* `MAKEFIFO`: `makefifo` location.
* `BURNFIFO`: `rm` location.
* `SORTTEXT`: `sort` location.
* `GREPTEXT`: `grep` location.
* `UNIXTIME`: `date` location.

The development utility, `qnetinfo-http-server.sh`, supports the following environment variables.

* `HTTPPORT`: Port to listen to.
* `HTTPFILE`: File to send.  For security reasons, as the server is super crude, `GET` or `HEAD` supplied URI is always discarded.

# Troubleshooting

Essentially all of the used AT commands are both vendor and firmware specific.  Therefore making this universally compatible, even with the above list, is extremely difficult.  Attempting to do this using very restrictive POSIX shell language does not help the task either.

Please see the script for the implementation details.  The processing is split in corresponding functions and naming convetion is anything but terse.  Therefore the script should be relatively easy to understand.

# License

Public domain, if used for good.