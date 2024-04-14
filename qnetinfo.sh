#!/usr/bin/env sh

# Public domain, if used for good.

# =============================================================================
#   QNETINFO
# -----------------------------------------------------------------------------
# Note: Extracts and represents network information from a  Quectel LTE  modem.

# Note: This  only uses a minimal number POSIX shell features that are  present
# in Busybox.  Therefore the code is unfortunately pretty ugly  and  unoptimal,
# as  no  better  options  are available  or  readily  usable.  This  stunt  is
# performed by trained professional, please do not attempt to re-create.

set +x
set -e
set -m

qnetinfo__printf ()
{

local format="${1:?argument-required}"; shift
printf -- \
"$format\n\c" \
    "$@"

}

qnetinfo__printf__inline ()
{

local format="${1:?argument-required}"; shift
printf -- \
"$format\c" \
    "$@"

}

qnetinfo__printf__crlf ()
{

local format="${1:?argument-required}"; shift
printf -- \
"$format\r\n\c" \
    "$@"

}

qnetinfo__prints ()
{

echo -n "$*"$'\n'

}

qnetinfo__prints__error ()
{

qnetinfo__printf \
'\e[91;1m%s\e[0m: %s.' 'error' "$*"
exit 1

}

qnetinfo__check__base10 ()
{

local p="${1:?argument-required}" P="${2:-}" v; eval 'v=${'"$p"'}'
    local \
    __v=${v#[-+]}
while [ -n "$__v" ]; do
    __v=${__v#[0-9]}
case "$__v" in
    [!0-9]*)
    qnetinfo__printf \
'`%s'\''=`%s'\'' unexpected, expected numeric (base-10) value.' \
    "${P:-$p}" "$v"
    return 1
    ;;
esac
done
    return 0

}

qnetinfo__check__base10__positive ()
{

if \
qnetinfo__check__base10 "$@"; then
local p="${1:?argument-required}" P="${2:-}" v; eval 'v=${'"$p"'}'
if [ "$v" -lt 0 ]; then
    qnetinfo__printf \
'`%s'\''=`%s'\'' unacceptable, must be positive.' \
    "${P:-$p}" "$v"
    return 1
else
    return 0
fi
else
    return 1
fi

}

qnetinfo__check__base16 ()
{

local p="${1:?argument-required}" P="${2:-}" v; eval 'v=${'"$p"'}'
    local \
    __v=${v#0[Xx]}
while [ -n "$__v" ]; do
    __v=${__v#[0-9A-Fa-f]}
case "$__v" in
    [!0-9A-Fa-f]*)
    qnetinfo__printf \
'`%s'\''=`%s'\'' unexpected, expected numeric (base-16) value.' \
    "${P:-$p}" "$v"
    return 1
    ;;
esac
done
    return 0

}

TTYAWAIT__DEFAULT=250
TTYAWAIT=${TTYAWAIT:-$TTYAWAIT__DEFAULT}
# Note: This must be either  `usbat'  or  `usbmodem',  but the first is usually
# taken by the router.
TTYMODEM__DEFAULT='/dev/ttyUSB3'
TTYMODEM=${TTYMODEM:-$TTYMODEM__DEFAULT}
TTYSPEED__DEFAULT=9600
TTYSPEED=${TTYSPEED:-$TTYSPEED__DEFAULT}
MICROCOM__DEFAULT='microcom'
MICROCOM=$(which -- $MICROCOM__DEFAULT) || qnetinfo__prints__error \
"microcom \`$MICROCOM__DEFAULT' not found"
LOGLEVEL__DEFAULT=0
LOGLEVEL=${LOGLEVEL:-$LOGLEVEL__DEFAULT}
GRANDCLK=0
AWOLTIME__DEFAULT=60
AWOLTIME=${AWOLTIME:-$AWOLTIME__DEFAULT}
OUTATIME__DEFAULT=300
OUTATIME=${OUTATIME:-$OUTATIME__DEFAULT}
INTERVAL__DEFAULT=10
INTERVAL=${INTERVAL:-$INTERVAL__DEFAULT}
PARALLEL__DEFAULT=4
PARALLEL=${PARALLEL:-$PARALLEL__DEFAULT}
ANYMODEM__DEFAULT=0
ANYMODEM=${ANYMODEM:-$ANYMODEM__DEFAULT}
MAKEFIFO__DEFAULT='mkfifo'
MAKEFIFO=$(which -- $MAKEFIFO__DEFAULT) || qnetinfo__prints__error \
"makefifo \`$MAKEFIFO__DEFAULT' not found"
BURNFIFO__DEFAULT='rm'
BURNFIFO=$(which -- $BURNFIFO__DEFAULT) || qnetinfo__prints__error \
"burnfifo \`$BURNFIFO__DEFAULT' not found"
SORTTEXT__DEFAULT='sort'
SORTTEXT=$(which -- $SORTTEXT__DEFAULT) || qnetinfo__prints__error \
"sorttext \`$SORTTEXT__DEFAULT' not found"
GREPTEXT__DEFAULT='grep'
GREPTEXT=$(which -- $GREPTEXT__DEFAULT) || qnetinfo__prints__error \
"greptext \`$GREPTEXT__DEFAULT' not found"
UNIXTIME__DEFAULT='date'
UNIXTIME=$(which -- $UNIXTIME__DEFAULT) || qnetinfo__prints__error \
"unixtime \`$UNIXTIME__DEFAULT' not found"


for p in \
    LOGLEVEL \
    ANYMODEM; do
    if ! qnetinfo__check__base10 "$p"; then
    eval "$p"'=${'"$p"'__DEFAULT:?default-required}'
    fi
done
for p in \
    TTYAWAIT \
    TTYSPEED \
    AWOLTIME \
    OUTATIME \
    INTERVAL \
    PARALLEL; do
    if ! qnetinfo__check__base10__positive "$p"; then
    eval "$p"'=${'"$p"'__DEFAULT:?default-required}'
    fi
done

[ -c "$TTYMODEM" ] && \
[ -r "$TTYMODEM" ] && \
[ -w "$TTYMODEM" ] || qnetinfo__prints__error \
"ttymodem (\`$TTYMODEM') not a readable and writeable character special file"

[ -x "$MICROCOM" ] || qnetinfo__prints__error \
"microcom (\`$MICROCOM') not executable"

FIFO='/tmp/qnetinfo__fifo'
DISP='/tmp/qnetinfo__fifo__display'

qnetinfo__fifo__acquire ()
{

for fifo in "$FIFO" "$DISP"; do
if [ ! -p "$fifo" ]; then
    $MAKEFIFO -- "$fifo"
fi
done

exec 5<> "$FIFO"
exec 6<> "$DISP"

}

qnetinfo__fifo__release ()
{

exec 6<&-
exec 5<&-

for fifo in "$FIFO" "$DISP"; do
if [ -p "$fifo" ]; then
    $BURNFIFO -- "$fifo"
fi
done

}

qnetinfo__trap ()
{

qnetinfo__fifo__release

qnetinfo__printf '\rtrap: %s.' "${1:-???}"
exit

}

qnetinfo__trap__arm ()
{

trap "qnetinfo__trap '${1:?argument-required}'" "$1"

}

for signal in EXIT HUP QUIT INT ABRT ALRM TERM; do
qnetinfo__trap__arm "$signal"
done

qnetinfo__fifo__acquire

qnetinfo__time ()
{
$UNIXTIME -- '+%s'
}

qnetinfo__fmt__class__small__current='33'
qnetinfo__fmt__class__small__current__active='33'
qnetinfo__fmt__class__small__current__normal='37'
qnetinfo__fmt__class__small__current__absent='37;2'
qnetinfo__fmt__class__small__current__unknow='90;2'
qnetinfo__fmt__class__large__current='93'
qnetinfo__fmt__class__large__current__active='93;1'
qnetinfo__fmt__class__large__current__normal='37'
qnetinfo__fmt__class__large__current__absent='97;2'
qnetinfo__fmt__class__large__current__unknow='90;2'
qnetinfo__fmt__class__other__current='37'
qnetinfo__fmt__class__other__current__active='37;1'
qnetinfo__fmt__class__other__current__normal='37'
qnetinfo__fmt__class__other__current__absent='37;2'
qnetinfo__fmt__class__other__current__unknow='90;2'
qnetinfo__fmt__class__value__current='35;1'
qnetinfo__fmt__class__value__current__active='95;1'
qnetinfo__fmt__class__value__current__normal='96'
qnetinfo__fmt__class__value__current__absent='90'
qnetinfo__fmt__class__value__current__unknow='90'
qnetinfo__fmt__class__limit__current='35;2'
qnetinfo__fmt__class__limit__current__active='35;2'
qnetinfo__fmt__class__limit__current__normal='37;2'
qnetinfo__fmt__class__limit__current__absent='90'
qnetinfo__fmt__class__limit__current__unknow='90;2'
qnetinfo__fmt__class__value__average='95'
qnetinfo__fmt__class__limit__average='95;2'

qnetinfo__fmt__title ()
{
qnetinfo__printf '\e[37;4;1m%s\e[0m' "$*";
}

h__y () { qnetinfo__printf '\e[33''m%s\e[0m' "$*"; }
h__c () { qnetinfo__printf '\e[36;1m%s\e[0m' "$*"; }
h__Y () { qnetinfo__printf '\e[93''m%s\e[0m' "$*"; }
h__C () { qnetinfo__printf '\e[96;1m%s\e[0m' "$*"; }
h__W () { qnetinfo__printf '\e[97''m%s\e[0m' "$*"; }

qnetinfo__at__parameter__classify ()
{

local p="${1:?argument-required}"
case "$p" in
   'v__common__s')
    qnetinfo__prints 'small__current' ;;
   'v__common__l')
    qnetinfo__prints 'large__current' ;;
   'v__common__o')
    qnetinfo__prints 'other__current' ;;

   'v__unique__s')
    qnetinfo__prints "small__current__${p__unique__fmt__state:-unknow}" ;;
   'v__unique__l')
    qnetinfo__prints "large__current__${p__unique__fmt__state:-unknow}" ;;
   'v__unique__o')
    qnetinfo__prints "other__current__${p__unique__fmt__state:-unknow}" ;;

   'p__common__min__'*'__avg'|\
   'p__common__max__'*'__avg'|\
   'p__unique__min__'*'__avg'|\
   'p__unique__max__'*'__avg')
    qnetinfo__prints 'limit__average' ;;

   'p__common__min__'*|\
   'p__common__max__'*)
    qnetinfo__prints 'limit__current' ;;
   'p__unique__min__'*|\
   'p__unique__max__'*)
    qnetinfo__prints "limit__current__${p__unique__fmt__state:-unknow}" ;;

   'p__common__val__'*'__avg'|\
   'p__unique__val__'*'__avg')
    qnetinfo__prints 'value__average' ;;

   'p__common__val__'*)
    qnetinfo__prints 'value__current' ;;

   'p__unique__val__'*)
    qnetinfo__prints "value__current__${p__unique__fmt__state:-unknow}" ;;
esac

}

qnetinfo__fmt__str ()
{

local p="${1:?argument-required}" v qnetinfo__fmt__string qnetinfo__fmt__class; shift
eval \
qnetinfo__fmt__class='${qnetinfo__fmt__class__'"$(qnetinfo__at__parameter__classify "$p")"'}'
qnetinfo__fmt=$*
qnetinfo__printf '\e[%sm%s\e[0m' \
    "$qnetinfo__fmt__class" "$qnetinfo__fmt"

}

qnetinfo__fmt__var ()
{

local p="${1:?argument-required}" v qnetinfo__fmt__string qnetinfo__fmt__class; eval v='${'"$p"'}'
if [ -z "$v" ]; then
local \
p__unique__fmt__state='unknow'
fi
eval \
qnetinfo__fmt__class='${qnetinfo__fmt__class__'"$(qnetinfo__at__parameter__classify "$p")"'}'
if [ -n "$v" ]; then
qnetinfo__fmt='%+03d'
else
qnetinfo__fmt='%3.3s'
fi
qnetinfo__printf '\e[%sm%s\e[0m' \
    "$qnetinfo__fmt__class" "$qnetinfo__fmt"

}

qnetinfo__val__var ()
{

local p="${1:?argument-required}" v; eval v='${'"$p"'}'
if [ -n "$v" ]; then
    qnetinfo__prints "$(( v > 99 ? 99 : v < -99 ? -99 : v ))"
else
    case "$p" in
    ?'__unique__'*)
    qnetinfo__prints '...' ;;
    ?'__common__'*|*)
    qnetinfo__prints '???' ;;
    esac
fi

}

__\
qnetinfo__mod ()
{

local q="${1:?argument-required}"
case "$q" in
0)  qnetinfo__prints    'QPSK' ;;
1)  qnetinfo__prints  '16-QAM' ;;
2)  qnetinfo__prints  '64-QAM' ;;
3)  qnetinfo__prints '256-QAM' ;;
*)  qnetinfo__prints '???????' ;;
esac

}

# Note: These simply use 2nd degree polynomial fitting, scaled so that a signed
# 32-bit  integer does not overflow.  There  is no  floating point support,  so
# the calculation is moved to fixed point domain.  Also,  by default values are
# rounded  down,  so  the values shall be adjusted  accordingly.  It  would  be
# possible to further tweak the selected scale, but for this use case the extra
# precision provides no value.

qnetinfo__cqi__var ()
{

# Note: The UE must support 256-QAM,  otherwise the reported  modulation scheme
# is  not  valid.  The lookup table,  and thus the polynomials,  are  different
# otherwise.

local p="${1:?argument-required}" v; eval v='${'"$p"'}'
if [ $v -lt 16 ]; then
  local q
# Note: -0.00719133807369102 * x**2 + 0.354347123464771 * x - 0.573626373626374
  q=$(( \
( (-0x001d74aa ) * v * v \
+ ( 0x05ab67e0 ) * v \
+ (-0x012d92da ) ) \
/ ( 0x10000000 ) \
     ))
__qnetinfo__mod $q
fi

}

qnetinfo__mcs__var ()
{

# Note: Ditto.

local p="${1:?argument-required}" v; eval v='${'"$p"'}'
if [ $v -lt 32 ]; then
  local q
if [ $v -lt 28 ]; then
# Note: -0.00223148499010568 * x**2 + 0.186686876342049 * x - 0.253694581280788
  q=$(( \
( (-0x000923e1 ) * v * v \
+ ( 0x02fcab60 ) * v \
+ ( 0x03f0ddf4 ) ) \
/ ( 0x10000000 ) \
     ))
else
  q=$(( v - 28 ))
fi
__qnetinfo__mod $q
fi

}

qnetinfo__chain ()
{

local IFS=','; set -- $*
# Note: Syntactic sugar.  Allows input elements to be aligned.
if [ $# -gt 0 ]; then
while [ $# -gt 1 ]; do
qnetinfo__printf__inline \
  '%s,' "${1:?argument-required}"
shift
done
qnetinfo__printf \
  '%s'  "${1:?argument-required}"
fi

}

export \
p__global__pci=

# E-UTRAN: Evolved Universal Terrestrial Radio Access Network
#     MCC: Mobile Country Code               ; 12 bits
#     MNC: Mobile Network Code               ;  8 bits or 12 bits
#     TAC: Tracking Area Code                ; 16 bits
#     eNB: Evolved Node B
#   eNBID: eNB Identifier                    ; 20 bits
#  CellID: Cell Identifier                   ;  8 bits
#    PLMN: Public Land Mobile Network        ; MCC + MNC
#     TAI: Tracking Area Identity            ; MCC + MNC + TAC
#     ECI: E-UTRAN Cell Identifier           ; eNBID + CellID
#    ECGI: E-UTRAN Cell Global Identifier    ; MCC + MNC + eNBID + CellID
#     CQI: Channel Quality Indicator
#            01 .. 03         QPSK           ; ... when 256-QAM supported
#            04 .. 06       16-QAM
#            07 .. 11       64-QAM
#            12 .. 15      256-QAM
#     MCS: Modulation Coding Scheme
#            00 .. 04, 28     QPSK           ; ... ditto.
#            05 .. 10, 29   16-QAM
#            11 .. 19, 30   64-QAM
#            20 .. 27, 31  256-QAM
#      RI: Rank Indicator
#     PMI: Precoding Matrix Index
#     PSS: Primary Synchronization Signal    ; 0 .. 2
#     SSS: Seconary Synchroniation Signal    ; 0 .. 167 (LTE)
#     PCI: Physical Cell Identity            ; PSS + 3 * SSS
#      CA: Channel Aggregation
#     PCC: Primary Cell Carrier Component
#     SCC: Secondary Cell Carrier Component

# Note: Parameters  that  are more or less common,  or  not reported  for  each
# cell, that the modem reports.
p__common__val=$(qnetinfo__chain \
      'mcc'                                                                    \
      'mnc'                                                                    \
      'tac'                                                                    \
      'eci')
p__common__val__minmax=$(qnetinfo__chain \
      'cqi'                                                                    \
      'mcs'                                                                    \
       'ri'                                                                    \
      'pmi'                                                                    \
     'tstp'                                                                    \
     'rsrp__ant0'                                                              \
     'rsrp__ant1'                                                              \
     'rsrp__ant2'                                                              \
     'rsrp__ant3')
p__common__avg=$(qnetinfo__chain \
      'cqi'                                                                    \
      'mcs'                                                                    \
       'ri'                                                                    \
      'pmi'                                                                    \
     'tstp'                                                                    \
     'rsrp__ant0'                                                              \
     'rsrp__ant1'                                                              \
     'rsrp__ant2'                                                              \
     'rsrp__ant3')

# Note: Parameters that are unique for each given (physical) cell identifier.
p__unique__val__volatile=$(qnetinfo__chain \
     'state'                                                                   \
     'state__lastseen')
p__unique__val=$(qnetinfo__chain \
      'pci'                                                                    \
   'earfcn'                                                                    \
     'type'                                                                    \
'bandwidth'                                                                    \
'bandwidth__ul'                                                                \
'bandwidth__dl'                                                                \
     'state'                                                                   \
     'state__lastseen')
p__unique__val__minmax=$(qnetinfo__chain \
     'rsrq'                                                                    \
     'rsrp'                                                                    \
     'rssi'                                                                    \
     'sinr')
p__unique__avg=$(qnetinfo__chain \
     'rsrq'                                                                    \
     'rsrp'                                                                    \
     'rssi'                                                                    \
     'sinr')

qnetinfo__calc__variable__avg ()
{

while [ $# -gt 0 ]; do

local p="${1:?argument-required}"
local p__name__avg="$p"'__avg'
local v v__avg; eval v='${'"$p"'}' v__avg='${'"$p__name__avg"':-${'"$p"'}}'
# Note: ``((v + 0.5) + (v__avg + 0.5)) / 2''.
if [ -n "$v" ]; then
  : $(( $p__name__avg = ( v * 10 + v__avg * 10 + 10 ) / 20 ))
fi

shift
done

}

qnetinfo__trim__variable ()
{

local WSP=$' \t\v'
while [ $# -gt 0 ]; do

eval "$1"'=${'"$1"'##['"$WSP"']}'
eval "$1"'=${'"$1"'%%['"$WSP"']}'

shift
done

}

qnetinfo__at__parameter__argument ()
{

local IFS=':'; set -- $*
p="${1:?argument-required}"
p__modifier="${2:-}"

}
qnetinfo__at__parameter ()
{

local P="${1:?argument-required}" p v="${2:?argument-required}" v__translate=t
qnetinfo__trim__variable P v

qnetinfo__at__parameter__argument $P
eval unset \
'p__'"$p"

if [ -n "$p__modifier" ]; then
case "$p__modifier" in
    *'~bypass-translate')
    p__modifier=${p__modifier%~*}
    v__translate=f
    ;;
esac

fi

case "${p__modifier:-default}" in
    'default')
    ;;

    'ignored')
[ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
    "$(h__y '%16s')"': `'"$(h__y '%s')"\'', ignored.' \
    "$p" "$v"
    return 0
    ;;

    'numeric__base10'|'numeric')
        qnetinfo__check__base10 "$p" "$P" || return 1
    ;;

    'numeric__base16'|'numeric__hex')
        qnetinfo__check__base16 "$p" "$P" || return 1
    ;;

    *)
        qnetinfo__printf \
    '`%s'\'' unknown.' \
        "$p__modifier"
        return 2
    ;;
esac

if [ "$v" = '-' ]; then
    qnetinfo__printf \
    '`%s'\'' missing.' "$P" >&2
    return 1
fi

[ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
    "$(h__Y '%16s')"': `'"$(h__W '%s')"\''.' \
        "$p" "$v"

if [ "$v__translate" = 't' ]; then
case "$p" in
    'bandwidth')
case "$v" in
6)  v=1.4
    ;;
*)  if [ $v -gt 6 ]; then
    v=$(( v / 5 ))
    fi
    ;;
esac
    ;;

    'bandwidth__'*)
case "$v" in
0)  v=1.4
    ;;
1)  v=3
    ;;
*)  if [ $v -gt 1 ]; then
    v=$(( (v - 1) * 5 ))
    fi
    ;;
esac
    ;;

    'state')
case "$at__response__type" in
    'PriCC')
case "$v" in
0)  v='!' ;; # Not serving
1)  v='R' ;; # Registered
*)  v='?' ;;
esac
    ;;

    'SecCC')
case "$v" in
0)  v='!' ;; # Not configured
1)  v='c' ;; # Configured, deactived
2)  v='C' ;; # Configured, activated
*)  v='?' ;;
esac
    ;;
    *)
    v='?'
    ;;
esac
    ;;

# Note: In  theory  `PCI 0'  is  valid.  In practice,  with this modem,  it  is
# errornously reported with incorrect  (all zero)  channel data.  At the moment
# prefiltering is not implemented, sorry.
    'pci')
if [ "$v" -le 0 ] \
|| [ "$v" -gt 503 ]; then
    return 1
fi
    ;;

    'tstp')
# Note: When the modem is "not transmitting" the value is reported as `-32768'.
# This goes a bit further and simply omit anything below  -100 dB.  This likely
# does  not include all transmission  given the value might remain invalid  for
# long periods.
if [ "$v" -lt -1000 ]; then
    return 1
fi
    v=$(( (v + 5) / 10 ))
    ;;

    'sinr')
# Note: As  extracted  from  the firmware.  This is  unlike  presented  in  any
# published documentation that either quote 3GPP or ``-20 + n / 5''.
    v=$(( (-10 + v) * 2 ))
    ;;
esac
fi

eval \
'p__'"$p"="$v"

return 0

}

qnetinfo__at ()
{

local IFS=':'; set -- $*
local \
at__command="${1:?argument-required}"; shift
qnetinfo__trim__variable \
at__command
local IFS=','; set -- $*

# Note: If the subtype is passed as the first parameter, attach it to the input
# AT command.
case "$at__command" in
    '+QENG'|'+QCAINFO'|'+QNETINFO')
local \
at__command__type="${1:?argument-required}"; shift
qnetinfo__trim__variable \
at__command__type
at__command="$at__command: $at__command__type";
esac

local \
at__response
local \
at__response__type

case "$at__command" in
    '+QENG: "servingcell"')
at__response=$(qnetinfo__chain \
        'state:ignored'                                                        \
   'technology:ignored'                                                        \
          'tdd:ignored'                                                        \
          'mcc:numeric'                                                        \
          'mnc:numeric'                                                        \
          'eci:numeric__hex'                                                   \
          'pci:numeric'                                                        \
       'earfcn:numeric'                                                        \
         'band:numeric'                                                        \
'bandwidth__ul:numeric'                                                        \
'bandwidth__dl:numeric'                                                        \
          'tac:numeric__hex'                                                   \
         'rsrp:numeric'                                                        \
         'rsrq:numeric'                                                        \
         'rssi:numeric'                                                        \
         'sinr:numeric'                                                        \
          'cqi:ignored'                                                        \
         'tstp:numeric') # ... rest ignored.
    ;;

    '+QENG: "neighbourcell '*'"')
at__response=$(qnetinfo__chain \
   'technology:ignored'                                                        \
       'earfcn:numeric'                                                        \
          'pci:numeric'                                                        \
         'rsrq:numeric'                                                        \
         'rsrp:numeric'                                                        \
         'rssi:numeric'                                                        \
         'sinr:ignored')
    ;;

    '+QCAINFO: "'*'"')
at__response=$(qnetinfo__chain \
       'earfcn:numeric'                                                        \
    'bandwidth:numeric'                                                        \
         'band:ignored'                                                        \
        'state:numeric'                                                        \
          'pci:numeric'                                                        \
         'rsrp:numeric'                                                        \
         'rsrq:numeric'                                                        \
         'rssi:numeric'                                                        \
         'sinr:numeric~bypass-translate')
    ;;

    '+QNETINFO: "servingcell"')
    local \
    at__command__subtype="{1:?argument-required}"; shift
case "$at__command__subtype" in
        '"PCC"')
at__response__type='PriCC'
at__response=$(qnetinfo__chain \
          'eci:numeric__hex'                                                   \
          'pci:numeric'                                                        \
       'earfcn:numeric'                                                        \
         'band:ignored'                                                        \
         'rsrp:numeric'                                                        \
         'rsrq:numeric'                                                        \
         'rssi:numeric'                                                        \
         'sinr:ignored'                                                        \
'bandwidth__dl:numeric'                                                        \
'bandwidth__ul:numeric'                                                        \
          'tac:ignored') # ... rest ignored.
    ;;
        '"SCC"')
at__response__type='SecCC'
at__response=$(qnetinfo__chain \
          'eci:numeric__hex'                                                   \
          'pci:numeric'                                                        \
       'earfcn:numeric'                                                        \
         'band:ignored'                                                        \
         'rsrp:numeric'                                                        \
         'rsrq:numeric'                                                        \
         'rssi:numeric'                                                        \
         'sinr:ignored'                                                        \
'bandwidth__dl:numeric')
    ;;

    *)
        qnetinfo__printf \
        '`%s'\'' unknown command (subtype), sorry.' \
            "$at__command__subtype" >&2
    return 1
    ;;
esac
    ;;

# CMR: Channel Measurement Report (?)
    '+QNETINFO: "cmr"')
at__response=$(qnetinfo__chain \
          'cqi:numeric'                                                        \
          'mcs:numeric'                                                        \
           'ri:numeric'                                                        \
          'pmi:numeric')
    ;;

    '+QRSRP')
at__response=$(qnetinfo__chain \
   'rsrp__ant0:numeric'                                                        \
   'rsrp__ant1:numeric'                                                        \
   'rsrp__ant2:numeric'                                                        \
   'rsrp__ant3:numeric')
    ;;

    *)
        qnetinfo__printf \
        '`%s'\'' unknown command, sorry.' \
            "$at__command" >&2
    return 1
    ;;
esac

if [ -z "$at__response__type" ]; then
# Note: Presence  of CA information will override any overlapping serving  cell
# information.  Namely, this type.
case "$at__command" in
    '+'*': "servingcell"')
at__response__type='PriSC'
    ;;
# Note: Neighbour cell using the same carrier (band) as the primary cell.
    '+'*': "neighbourcell intra"')
at__response__type='Intra'
    ;;
# Note: Neighbour cell using a different carrier.
    '+'*': "neighbourcell inter"')
at__response__type='Inter'
    ;;
    '+'*': "pcc"')
at__response__type='PriCC'
    ;;
    '+'*': "scc"')
at__response__type='SecCC'
    ;;
esac
fi

local \
p__state__lastseen=$GRANDCLK
if [ -n "$at__response__type" ]; then
local \
p__type="$at__response__type"
fi

for p in $p__common__avg $p__common__val $p__unique__avg $p__unique__val; do
    eval local \
   'p__'"$p"
done

for P in $at__response; do
local \
qnetinfo__at__parameter__result=0
qnetinfo__at__parameter "$P" "${1:?argument-required}" || \
qnetinfo__at__parameter__result=$?; shift
    case "$p__modifier" in
        'ignored')
            ;;
        'numeric'|'numeric__'*)
    if [ $qnetinfo__at__parameter__result ]; then
    eval local \
   'p__'"$p"'__present'='y'
    else
    eval unset \
   'p__'"$p"'__present'
    fi
            ;;
    esac
done

for p in $p__common__avg $p__common__val; do
    eval local \
 '__p'='$p__'"$p" \
 '__p__present'='$p__'"$p"'__present'

    if [ -z "$__p" ]; then
        if [ -n "$__p__present" ]; then
# Note: If no value is defined, but the variable was set, the value is regarded
# invalid.  Not only the current value is undefined,  but the previously stored
# value, too.
        eval unset \
   'p__common__val__'"$p"
        fi
    else
        eval \
   'p__common__val__'"$p"='"$__p"'
    fi
done

for p in $p__common__val__minmax; do
    eval local \
 '__p'='$p__'"$p" \
 '__p__present'='$p__'"$p"'__present'
    if [ -n "$__p" ]; then
# Note: Any minimum / maximum values are not touched,  should the current value
# be ragarded as invalid.
    eval local \
 '__p__common__min'='"$p__common__min__'"$p"'"' \
 '__p__common__max'='"$p__common__max__'"$p"'"'

    if [ -z "$__p__common__min" ] \
    || [ "$__p__common__min" -gt "$__p" ]; then
        eval \
   'p__common__min__'"$p"='"$__p"'
    fi

    if [ -z "$__p__common__min" ] \
    || [ "$__p__common__max" -lt "$__p" ]; then
        eval \
   'p__common__max__'"$p"='"$__p"'
    fi
    fi
done

if [ -n "$p__pci" ]; then

    eval local \
'__p__global__pci'='$p__global__pci__'"$p__pci"
if [ -z "$__p__global__pci" ]; then
    eval \
   'p__global__pci__'"$p__pci"='"$p__pci"'
    p__global__pci=$(printf -- '%s\n%s' \
          "$p__pci" \
  "$p__global__pci" \
        | $SORTTEXT -n)
fi

for p in $p__unique__val__volatile; do
    eval local \
   'p__'"$p"'__present'='*'
done

for p in $p__unique__avg $p__unique__val; do
    eval local \
 '__p'='$p__'"$p" \
 '__p__present'='$p__'"$p"'__present'

    if [ -z "$__p" ]; then
        if [ -n "$__p__present" ]; then
        eval unset \
   'p__unique__val__'"$p"'__'"$p__pci"
        fi
    else
        eval \
   'p__unique__val__'"$p"'__'"$p__pci"='"$__p"'
    fi
done

for p in $p__unique__val__minmax; do
    eval local \
 '__p'='$p__'"$p" \
' __p__present'='$p__'"$p"'__present'
    if [ -n "$__p" ]; then
        eval local \
 '__p__unique__min'='"$p__unique__min__'"$p"'__'"$p__pci"'"' \
 '__p__unique__max'='"$p__unique__max__'"$p"'__'"$p__pci"'"'

    if [ -z "$__p__unique__min" ] \
    || [ "$__p__unique__min" -gt "$__p" ]; then
        eval \
   'p__unique__min__'"$p"'__'"$p__pci"='"$__p"'
    fi

    if [ -z "$__p__unique__min" ] \
    || [ "$__p__unique__max" -lt "$__p" ]; then
        eval \
   'p__unique__max__'"$p"'__'"$p__pci"='"$__p"'
    fi
    fi
done

fi

}


qnetinfo__printf__result ()
{

qnetinfo__printf "$@" >&6

}

qnetinfo__prints__result__common ()
{

    local IFS=','
for p in $p__common__avg; do
    qnetinfo__calc__variable__avg \
   'p__common__val__'"$p"
done
for p in $p__common__val__minmax; do
    qnetinfo__calc__variable__avg \
   'p__common__min__'"$p" \
   'p__common__max__'"$p"
done

qnetinfo__printf__result \
"$(qnetinfo__fmt__title '%-03s') "\
"$(qnetinfo__fmt__title '%-03s') "\
"$(qnetinfo__fmt__title '%-04s') "\
"$(qnetinfo__fmt__title '%-19s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s')" \
            'MCC' \
            'MNC' \
            'TAC' \
   'eNBID:CELLID' \
"$(qnetinfo__cqi__var 'p__common__val__cqi') CQI" \
"$(qnetinfo__mcs__var 'p__common__val__mcs') MCS" \
             'RI' \
            'PMI'

qnetinfo__printf__result \
"$(qnetinfo__fmt__str 'v__common__o' '%03X') "\
"$(qnetinfo__fmt__str 'v__common__o' '%03X') "\
"$(qnetinfo__fmt__str 'v__common__o' '%04X') "\
"$(qnetinfo__fmt__str 'v__common__l' '%05X:%02X(%09u)') "\
"$(qnetinfo__fmt__var 'p__common__min__cqi')\
 $(qnetinfo__fmt__var 'p__common__val__cqi')\
 $(qnetinfo__fmt__var 'p__common__max__cqi') "\
"$(qnetinfo__fmt__var 'p__common__min__mcs')\
 $(qnetinfo__fmt__var 'p__common__val__mcs')\
 $(qnetinfo__fmt__var 'p__common__max__mcs') "\
"$(qnetinfo__fmt__var 'p__common__min__ri')\
 $(qnetinfo__fmt__var 'p__common__val__ri')\
 $(qnetinfo__fmt__var 'p__common__max__ri') "\
"$(qnetinfo__fmt__var 'p__common__min__pmi')\
 $(qnetinfo__fmt__var 'p__common__val__pmi')\
 $(qnetinfo__fmt__var 'p__common__max__pmi')" \
                    "${p__common__val__mcc:-0}" \
                    "${p__common__val__mnc:-0}" \
                  "0x${p__common__val__tac:-0}" \
              "$(( 0x${p__common__val__eci:-0} >> 8 ))" \
              "$(( 0x${p__common__val__eci:-0} & 15 ))" \
                  "0x${p__common__val__eci:-0}" \
"$(qnetinfo__val__var 'p__common__min__cqi')" \
"$(qnetinfo__val__var 'p__common__val__cqi')" \
"$(qnetinfo__val__var 'p__common__max__cqi')" \
"$(qnetinfo__val__var 'p__common__min__mcs')" \
"$(qnetinfo__val__var 'p__common__val__mcs')" \
"$(qnetinfo__val__var 'p__common__max__mcs')" \
"$(qnetinfo__val__var 'p__common__min__ri')" \
"$(qnetinfo__val__var 'p__common__val__ri')" \
"$(qnetinfo__val__var 'p__common__max__ri')" \
"$(qnetinfo__val__var 'p__common__min__pmi')" \
"$(qnetinfo__val__var 'p__common__val__pmi')" \
"$(qnetinfo__val__var 'p__common__max__pmi')"

qnetinfo__printf__result \
"%-32s "\
"$(qnetinfo__fmt__var 'p__common__min__cqi__avg')\
 $(qnetinfo__fmt__var 'p__common__val__cqi__avg')\
 $(qnetinfo__fmt__var 'p__common__max__cqi__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__mcs__avg')\
 $(qnetinfo__fmt__var 'p__common__val__mcs__avg')\
 $(qnetinfo__fmt__var 'p__common__max__mcs__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__ri__avg')\
 $(qnetinfo__fmt__var 'p__common__val__ri__avg')\
 $(qnetinfo__fmt__var 'p__common__max__ri__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__pmi__avg')\
 $(qnetinfo__fmt__var 'p__common__val__pmi__avg')\
 $(qnetinfo__fmt__var 'p__common__max__pmi__avg')" \
    '(average)' \
"$(qnetinfo__val__var 'p__common__min__cqi__avg')" \
"$(qnetinfo__val__var 'p__common__val__cqi__avg')" \
"$(qnetinfo__val__var 'p__common__max__cqi__avg')" \
"$(qnetinfo__val__var 'p__common__min__mcs__avg')" \
"$(qnetinfo__val__var 'p__common__val__mcs__avg')" \
"$(qnetinfo__val__var 'p__common__max__mcs__avg')" \
"$(qnetinfo__val__var 'p__common__min__ri__avg')" \
"$(qnetinfo__val__var 'p__common__val__ri__avg')" \
"$(qnetinfo__val__var 'p__common__max__ri__avg')" \
"$(qnetinfo__val__var 'p__common__min__pmi__avg')" \
"$(qnetinfo__val__var 'p__common__val__pmi__avg')" \
"$(qnetinfo__val__var 'p__common__max__pmi__avg')"

qnetinfo__printf__result \
               "%-20s "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s')" \
' '        'TSTP' \
    '(ANT0) RSRP' \
    '(ANT1) RSRP' \
    '(ANT2) RSRP' \
    '(ANT3) RSRP'

qnetinfo__printf__result \
"%-20s "\
"$(qnetinfo__fmt__var 'p__common__min__tstp')\
 $(qnetinfo__fmt__var 'p__common__val__tstp')\
 $(qnetinfo__fmt__var 'p__common__max__tstp') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant0')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant0')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant0') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant1')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant1')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant1') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant2')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant2')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant2') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant3')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant3')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant3')" ' ' \
"$(qnetinfo__val__var 'p__common__min__tstp')" \
"$(qnetinfo__val__var 'p__common__val__tstp')" \
"$(qnetinfo__val__var 'p__common__max__tstp')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant0')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant0')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant0')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant1')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant1')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant1')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant2')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant2')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant2')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant3')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant3')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant3')"

qnetinfo__printf__result \
"%-20s "\
"$(qnetinfo__fmt__var 'p__common__min__tstp__avg')\
 $(qnetinfo__fmt__var 'p__common__val__tstp__avg')\
 $(qnetinfo__fmt__var 'p__common__max__tstp__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant0__avg')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant0__avg')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant0__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant1__avg')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant1__avg')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant1__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant2__avg')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant2__avg')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant2__avg') "\
"$(qnetinfo__fmt__var 'p__common__min__rsrp__ant3__avg')\
 $(qnetinfo__fmt__var 'p__common__val__rsrp__ant3__avg')\
 $(qnetinfo__fmt__var 'p__common__max__rsrp__ant3__avg')" \
    '(average)' \
"$(qnetinfo__val__var 'p__common__min__tstp__avg')" \
"$(qnetinfo__val__var 'p__common__val__tstp__avg')" \
"$(qnetinfo__val__var 'p__common__max__tstp__avg')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant0__avg')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant0__avg')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant0__avg')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant1__avg')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant1__avg')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant1__avg')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant2__avg')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant2__avg')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant2__avg')" \
"$(qnetinfo__val__var 'p__common__min__rsrp__ant3__avg')" \
"$(qnetinfo__val__var 'p__common__val__rsrp__ant3__avg')" \
"$(qnetinfo__val__var 'p__common__max__rsrp__ant3__avg')"

}

qnetinfo__prints__result__unique ()
{

qnetinfo__printf__result \
"$(qnetinfo__fmt__title '%-03s') "\
"$(qnetinfo__fmt__title '%-03s') "\
"$(qnetinfo__fmt__title '%-03s') "\
"$(qnetinfo__fmt__title '%-06s') "\
"$(qnetinfo__fmt__title '%-02s') "\
"$(qnetinfo__fmt__title '%-02s') "\
"$(qnetinfo__fmt__title '%-01s') "\
"$(qnetinfo__fmt__title '%-05s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s') "\
"$(qnetinfo__fmt__title '%+11s')" \
             'SSS' \
             'PSS' \
             'PCI' \
          'EARFCN' \
              'DL' \
              'UL' \
               '+' \
            'TYPE' \
            'RSRQ' \
            'RSRP' \
            'RSSI' \
            'SINR'

    local IFS=$'\n'
    local parallel=0
for p__pci in $p__global__pci; do
    local IFS=','

for p in $p__unique__val $p__unique__avg; do
    eval local \
   'p__unique__val__'"$p"='"$p__unique__val__'"$p"'__'"$p__pci"'"'
done
for p in $p__unique__val__minmax; do
    eval local \
   'p__unique__min__'"$p"='"$p__unique__min__'"$p"'__'"$p__pci"'"' \
   'p__unique__max__'"$p"='"$p__unique__max__'"$p"'__'"$p__pci"'"'
done

if [ $outatime -gt 0 ] && [ $GRANDCLK -gt $(( outatime + \
    p__unique__val__state__lastseen )) ]; then

for p in $p__unique__val $p__unique__val__volatile $p__unique__avg; do
    eval unset \
   'p__unique__val__'"$p"'__'"$p__pci"
done
for p in $p__unique__val__minmax; do
    eval unset \
   'p__unique__min__'"$p"'__'"$p__pci" \
   'p__unique__max__'"$p"'__'"$p__pci"
done

    p__global__pci=$(printf -- '%s' \
  "$p__global__pci" \
      | $GREPTEXT -vw -- \
          "$p__pci")

    continue

fi

local p__unique__fmt__state

if [ $awoltime -gt 0 ] && [ $GRANDCLK -gt $(( awoltime + \
    p__unique__val__state__lastseen )) ]; then

for p in $p__unique__val__volatile; do
    if [[ "$p" = 'state__lastseen' ]]; then
      continue
    fi
    eval unset \
   'p__unique__val__'"$p" \
   'p__unique__val__'"$p"'__'"$p__pci"
done

    p__unique__fmt__state=absent
    else

    case "$p__unique__val__type" in
      'Pri'??|'Sec'??)
    p__unique__fmt__state=active ;;
      *)
    p__unique__fmt__state=normal ;;
    esac

    for p in $p__unique__avg; do
        qnetinfo__calc__variable__avg \
   'p__unique__val__'"$p"
    done
    for p in $p__unique__val__minmax; do
        qnetinfo__calc__variable__avg \
   'p__unique__min__'"$p" \
   'p__unique__max__'"$p"
  done

  fi

if [ -n "$p__unique__val__bandwidth" ]; then
    if [ -z "$p__unique__val__bandwidth__dl" ]; then
    p__unique__val__bandwidth__dl=$p__unique__val__bandwidth
    fi
    if [ -z "$p__unique__val__bandwidth__ul" ]; then
    p__unique__val__bandwidth__ul=$p__unique__val__bandwidth
    fi
fi

# Note: This is very crude and suboptiomal,  but there is no straighforward way
# to  limit the number of parallel processes.  Letting this freerun is likely a
# bit  faster,  albeit not optimal either,  but causes  resource starvation and
# subsequent lockup on small embedded systems.
if [ $(( parallel += 1 )) -gt $PARALLEL ]; then
wait
parallel=0
fi

qnetinfo__printf__result \
"$(qnetinfo__fmt__str 'v__unique__s'  '%03u')  "\
"$(qnetinfo__fmt__str 'v__unique__s'  '%01u')  "\
"$(qnetinfo__fmt__str 'v__unique__o'  '%03u')  "\
"$(qnetinfo__fmt__str 'v__unique__l'  '%04u')  "\
"$(qnetinfo__fmt__str 'v__unique__l'  '%02s') "\
"$(qnetinfo__fmt__str 'v__unique__l'  '%02s') "\
"$(qnetinfo__fmt__str 'v__unique__o'  '%01c') "\
"$(qnetinfo__fmt__str 'v__unique__s'  '%05s') "\
"$(qnetinfo__fmt__var 'p__unique__min__rsrq')\
 $(qnetinfo__fmt__var 'p__unique__val__rsrq')\
 $(qnetinfo__fmt__var 'p__unique__max__rsrq') "\
"$(qnetinfo__fmt__var 'p__unique__min__rsrp')\
 $(qnetinfo__fmt__var 'p__unique__val__rsrp')\
 $(qnetinfo__fmt__var 'p__unique__max__rsrp') "\
"$(qnetinfo__fmt__var 'p__unique__min__rssi')\
 $(qnetinfo__fmt__var 'p__unique__val__rssi')\
 $(qnetinfo__fmt__var 'p__unique__max__rssi') "\
"$(qnetinfo__fmt__var 'p__unique__min__sinr')\
 $(qnetinfo__fmt__var 'p__unique__val__sinr')\
 $(qnetinfo__fmt__var 'p__unique__max__sinr')" \
                  "$(( p__unique__val__pci / 3 ))"\
                  "$(( p__unique__val__pci % 3 ))"\
                     "$p__unique__val__pci" \
                     "$p__unique__val__earfcn" \
                     "$p__unique__val__bandwidth__dl" \
                     "$p__unique__val__bandwidth__ul" \
                    "${p__unique__val__state:- }" \
                     "$p__unique__val__type" \
"$(qnetinfo__val__var 'p__unique__min__rsrq')" \
"$(qnetinfo__val__var 'p__unique__val__rsrq')" \
"$(qnetinfo__val__var 'p__unique__max__rsrq')" \
"$(qnetinfo__val__var 'p__unique__min__rsrp')" \
"$(qnetinfo__val__var 'p__unique__val__rsrp')" \
"$(qnetinfo__val__var 'p__unique__max__rsrp')" \
"$(qnetinfo__val__var 'p__unique__min__rssi')" \
"$(qnetinfo__val__var 'p__unique__val__rssi')" \
"$(qnetinfo__val__var 'p__unique__max__rssi')" \
"$(qnetinfo__val__var 'p__unique__min__sinr')" \
"$(qnetinfo__val__var 'p__unique__val__sinr')" \
"$(qnetinfo__val__var 'p__unique__max__sinr')" &

done
wait

qnetinfo__printf__result \
'%-32s '\
"$(qnetinfo__fmt__var 'p__unique__min__rsrq__avg')\
 $(qnetinfo__fmt__var 'p__unique__val__rsrq__avg')\
 $(qnetinfo__fmt__var 'p__unique__max__rsrq__avg') "\
"$(qnetinfo__fmt__var 'p__unique__min__rsrp__avg')\
 $(qnetinfo__fmt__var 'p__unique__val__rsrp__avg')\
 $(qnetinfo__fmt__var 'p__unique__max__rsrp__avg') "\
"$(qnetinfo__fmt__var 'p__unique__min__rssi__avg')\
 $(qnetinfo__fmt__var 'p__unique__val__rssi__avg')\
 $(qnetinfo__fmt__var 'p__unique__max__rssi__avg') "\
"$(qnetinfo__fmt__var 'p__unique__min__sinr__avg')\
 $(qnetinfo__fmt__var 'p__unique__val__sinr__avg')\
 $(qnetinfo__fmt__var 'p__unique__max__sinr__avg')" \
    '(average)' \
"$(qnetinfo__val__var 'p__unique__min__rsrq__avg')" \
"$(qnetinfo__val__var 'p__unique__val__rsrq__avg')" \
"$(qnetinfo__val__var 'p__unique__max__rsrq__avg')" \
"$(qnetinfo__val__var 'p__unique__min__rsrp__avg')" \
"$(qnetinfo__val__var 'p__unique__val__rsrp__avg')" \
"$(qnetinfo__val__var 'p__unique__max__rsrp__avg')" \
"$(qnetinfo__val__var 'p__unique__min__rssi__avg')" \
"$(qnetinfo__val__var 'p__unique__val__rssi__avg')" \
"$(qnetinfo__val__var 'p__unique__max__rssi__avg')" \
"$(qnetinfo__val__var 'p__unique__min__sinr__avg')" \
"$(qnetinfo__val__var 'p__unique__val__sinr__avg')" \
"$(qnetinfo__val__var 'p__unique__max__sinr__avg')"

}

qnetinfo__prints__result ()
{

qnetinfo__prints__result__common
qnetinfo__prints__result__unique

qnetinfo__prints >&6

while IFS= read -r line <&6; do
    if [ -z "$line" ]; then
        break
    fi
    qnetinfo__prints "$line"
done

}

qnetinfo__at__query ()
{

local at__request="${1:?argument-required}" at__response__varname="${2:-}"
local at__response at__response__last
local IFS=$'\r\n'
local O=OK E=ERROR

qnetinfo__printf__crlf '%s' "$at__request" \
        | \
    $MICROCOM \
        ${TTYAWAIT:+-t$TTYAWAIT} \
        ${TTYSPEED:+-s$TTYSPEED} $TTYMODEM \
        | \
        { \
while read -r at__response; do
    if [ -z "$at__response" ]; then
        continue
    fi

    case "$at__response" in
        +*)
    qnetinfo__prints "$at__response" >&5
    at__response__last="${at__response__last:+$at__response__last;$IFS}$at__response"
        ;;
        $O)
    if [ -n "$at__response__last" ]; then
    [ $LOGLEVEL -gt 0 ] && qnetinfo__printf \
    'success `'"$(h__C '%s')"\'', ``\n%s'\'\''.' \
        "$at__request" \
        "$at__response__last"
    else
    [ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
    'success.'
    fi
    at__response__last=
        ;;
        $E)
    qnetinfo__printf \
    'failure?'
    at__response__last=
        ;;
      AT+*)
    [ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
    'ignored `'"$(h__c '%s')"\''.' \
        "$at__response"
        ;;
        ?*)
    qnetinfo__prints "$at__response" >&5
    [ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
    'content `'"$(h__c '%s')"\''.' \
        "$at__response"
    esac
done
    qnetinfo__prints '-' >&5
        }

while read -r at__response <&5; do
    case "$at__response" in
        +*)
    qnetinfo__at \
        "$at__response"
        ;;
        -*)
    break
        ;;
        **)
    if [ -n "$at__response__varname" ]; then
        eval \
        "$at__response__varname=\${at__response}"
    else
    [ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
'ignored response: %s.' \
        "$at__response"
    fi
        ;;
    esac
done

}

qnetinfo__main__verify ()
{

local modem__manufacturer modem__model modem__model__firmware

qnetinfo__at__query 'AT+GMI' modem__manufacturer
if [ -n "$modem__manufacturer" ]; then
case "$modem__manufacturer" in
    [Qq][Uu][Ee][Cc][Tt][Ee][Ll])
        ;;

    *)
# Note: All the used AT commands are vendor specific.  There is next to nothing
# to do, unless you are using a modem from this very manufacturer.
    qnetinfo__prints__error \
"modem manufacturer (\`$modem__manufacturer') unknown"
        ;;
esac
else
    qnetinfo__prints__error \
'modem manufacturer not detected'
fi

qnetinfo__at__query 'AT+GMM' modem__model
if [ -n "$modem__model" ]; then
case "$modem__model" in
    'EM12'|'EG12'|'EG18')
        ;;

    *)
# Note: Please  use  `ANYMODEM=1 ./qnetinfo.sh`  to  easily ignore  this.  Your
# mileage may vary to large degree, as all bets are off.
    [ $ANYMODEM -le 0 ] && qnetinfo__prints__error \
"modem model (\`$modem__model') unknown"
        ;;
esac

qnetinfo__at__query 'AT+GMR' modem__model__firmware

    qnetinfo__printf \
"info: modem model \`$(qnetinfo__fmt__str 'v__common__l' '%s')' (firmware \`$(qnetinfo__fmt__str 'v__common__s' '%s')')." \
    "$modem__model" \
   "${modem__model__firmware:-unknown}"
else
    [ $ANYMODEM -le 1 ] && qnetinfo__prints__error \
'modem model not detected'
fi

}

qnetinfo__main ()
{

qnetinfo__main__verify

deltaclk__interval=$(( INTERVAL >= 0 ? INTERVAL : 0 ))
# Note: If OUTATIME exceeds AWOLTIME, then the latter is simply ineffictive.
awoltime=$(( AWOLTIME >= 1 ? AWOLTIME : AWOLTIME__DEFAULT ))
outatime=$(( OUTATIME >= 1 ? OUTATIME : OUTATIME__DEFAULT ))

qnetinfo__prints \
'note, press control-c to stop ...' # or send an interrupt by some other mean.

while true; do

GRANDCLK=$(qnetinfo__time)

qnetinfo__at__query 'AT+QNETINFO="cmr"'
qnetinfo__at__query 'AT+QRSRP'
qnetinfo__at__query 'AT+QENG="neighbourcell"'
qnetinfo__at__query 'AT+QENG="servingcell"'
qnetinfo__at__query 'AT+QCAINFO'

# Note: `AT+QNETINFO="servingcell"' provides no additional information.

qnetinfo__prints__result
grandclk=$(qnetinfo__time)
deltaclk=$(( grandclk >= GRANDCLK ? grandclk - GRANDCLK : 0 ))
[ $LOGLEVEL -gt 0 ] && qnetinfo__printf \
'running took `'"$(h__Y '%s')"\'' second(s).' \
    "$deltaclk"
if [ $deltaclk__interval -gt 0 ]; then
deltaclk__interval__sleep=$(( deltaclk < deltaclk__interval ? deltaclk__interval - deltaclk : 0 ))
if [ $deltaclk__interval__sleep -gt 0 ]; then
[ $LOGLEVEL -gt 1 ] && qnetinfo__printf__inline \
'waiting `'"$(h__Y '%s')"\'' second(s), interval `'"$(h__y '%s')"\'' second(s) ...' \
    "$deltaclk__interval__sleep" \
    "$deltaclk__interval"
sleep $deltaclk__interval__sleep
[ $LOGLEVEL -gt 1 ] && qnetinfo__printf 'continuing.'
else
[ $LOGLEVEL -gt 1 ] && qnetinfo__printf \
'already late!'
fi
fi

done

}

qnetinfo__main

# See you later, space cowboy.
