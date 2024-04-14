#!/usr/bin/env bash

# Public domain, if used for good.

# =============================================================================
#   QNETINFO, HTTP SERVER
# -----------------------------------------------------------------------------
# Note: This can be used to transport the actual script to the modem host.

# Note: Sorry. I just cannot help myself.
set +x
set -e; sh\
opt -s extglob

declare -r \
HTTPPORT__DEFAULT=21569 \
HTTPFILE__DEFAULT="${0%-http-server.sh}.sh"
HTTPPORT="${HTTPPORT:-${HTTPPORT__DEFAULT}}"
# Note: The file sent is always fixed, for a reason, regardless of the request.
HTTPFILE="${HTTPFILE:-${HTTPFILE__DEFAULT}}"

function \
qnetinfo__printf ()
{

local format="${1:?argument-required}"; shift
builtin printf -- "${format}\n" "$@"

}

function \
qnetinfo__prints ()
{

builtin echo -n "$*"$'\n'

}

function \
qnetinfo__printf__error ()
{

qnetinfo__printf "$@"
exit 1

}

bash_version=$(( BASH_VERSINFO[0] * 10 + BASH_VERSINFO[1] % 10 ))
bash_version__required=52
if [[ "${bash_version}" -lt "${bash_version__required}" ]]; then
    qnetinfo__printf__error \
        'too old: bash reports version `%s'\'' (``%s'\'\''), required `%s'\''.' \
 "${bash_version}" \
 "${BASH_VERSION}" \
 "${bash_version__required}"
fi

declare -A \
 a__application=(\
   [CONCAT]=cat \
   [MD5SUM]=md5sum? \
   [TYPEOF]=file? \
   [STATOF]=stat? \
   [NETCAT]=netcat \
   [MKFIFO]=mkfifo \
   [RMFIFO]=rm
)

FIFO=/tmp/qnetinfo__fifo__send

for APPLICATION in "${!a__application[@]}"; do
    application=${a__application[${APPLICATION}]}
    application__name=${application%\?}
    declare \
  ${APPLICATION}="$(builtin command -v -- \
  ${application__name})"
    if [[ ! -x \
"${!APPLICATION}" ]]; then
        unset \
 "${APPLICATION}"
    fi
    case "${application}" in
        ?*\?)
    if [[ ! -v \
  ${APPLICATION} ]]; then
        qnetinfo__printf \
            'missing: %s, ignored.' \
 "${application__name}"
    fi
            ;;
        ???*)
    if [[ ! -v \
  ${APPLICATION} ]]; then
        qnetinfo__printf__error \
            'missing: %s.' \
 "${application__name}"
    fi
            ;;
    esac

    if [ -v \
  ${APPLICATION} ]; then
    readonly \
  ${APPLICATION}
    fi
done

function \
qnetinfo__trap ()
{

qnetinfo__printf '+ trap: %s.' "$*"

exec 5<&-
if [ -p "${FIFO}" ]; then
    $RMFIFO -- "${FIFO}"
fi

}

for signal in EXIT HUP QUIT INT ABRT ALRM TERM; do
trap "qnetinfo__trap '${signal@L}'" "${signal}"
done
if [ ! -p "${FIFO}" ]; then
    $MKFIFO -- "${FIFO}"
fi
exec 5<> "${FIFO}"


function \
qnetinfo__printf__crlf ()
{

local format="${1:?argument-required}"; shift
builtin printf -- "${format}\r\n" "$@"

}

function \
qnetinfo__prints__crlf ()
{

builtin echo -n "$*"$'\r\n'
}

function \
qnetinfo__http__recv ()
{

$NETCAT -l -p "${HTTPPORT:?httpport}" -q 1 -w 1

}

function \
qnetinfo__http__send ()
{

while IFS=$'\r\n' read send; do
    if [[ -n "${send}" ]]; then
        qnetinfo__printf \
'< %s' \
  "${send}" >&2
        qnetinfo__printf__crlf \
'%.4096s' \
  "${send}"
    else
        qnetinfo__prints \
'<' >&2
        qnetinfo__prints__crlf
        break
    fi
done

$CONCAT -- -

}

function \
qnetinfo__file__get__hash__md5 ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

if [[ -v MD5SUM ]]; then
local \
    md5sum=$( \
   $MD5SUM --binary -- "${file}" ) # ... not cutting ourselves here.

if [[ $? && -n md5sum && "${md5sum}" =~ ^([[:xdigit:]]{32}) ]]; then
    md5sum="${BASH_REMATCH[1]@L}"
    builtin echo -n \
 "${md5sum}"
    return 0
fi
fi

fi
    return 1

}

function \
qnetinfo__file__get__size ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

if [[ -v STATOF ]]; then
local \
    statof=$( \
   $STATOF --format='%s' -- "${file}" )

if [[ $? && -n statof && "${statof}" == +([[:digit:]]) ]]; then
    builtin echo -n \
 "${statof}"
    return 0
fi
fi

fi
    return 1

}

function \
qnetinfo__file__get__time__lastmodified ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

if [[ -v STATOF ]]; then
local \
    statof=$( \
   $STATOF --format='%Y' -- "${file}" )

if [[ $? && -n statof && "${statof}" == +([[:digit:]]) ]]; then
    TZ='GMT' \
    builtin printf -- '%(%a, %d %b %Y %T %Z)T' \
 "${statof}"
    return 0
fi
fi

fi
    return 1

}

function \
qnetinfo__file__get__mimetype ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

if [[ -v TYPEOF ]]; then
local \
    typeof=$( \
   $TYPEOF --brief --mime -- "${file}" )

if [[ $? && -n typeof ]]; then
    builtin echo -n \
 "${typeof}"
    return 0
fi
fi

fi
    return 1

}

function \
qnetinfo__http__get ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

local \
    file__mimetype \
    file__mimetype__default='text/plain' \
    file__size \
    file__hash__md5 \
    file__lastmodified

declare -A \
 a__resp__header__file=( \
   [file__mimetype]='Content-Type' \
   [file__size]='Content-Length' \
   [file__hash__md5]='Content-Hash-MD5' \
   [file__time__lastmodified]='Last-Modified'
    )

    file__mimetype=$( \
qnetinfo__file__get__mimetype \
 "${file}" ) || \
    file__mimetype="${file__mimetype__default}" || unset \
    file__mimetype

    file__size=$( \
qnetinfo__file__get__size \
 "${file}" ) || unset \
    file__size

# Note: Plain and simple, it just works.  Zero transcoding.  No funny business.
# Nothing supports `Content-Digest'.  Small platforms have no Base64, let alone
# any modern hash implementations working out of the box.
    file__hash__md5=$( \
qnetinfo__file__get__hash__md5 \
 "${file}" ) || unset \
    file__hash__md5

    file__time__lastmodified=$( \
qnetinfo__file__get__time__lastmodified \
 "${file}" ) || unset \
    file__time__lastmodified

    resp__status=200

for resp__header in "${!a__resp__header__file[@]}"; do
    if [[ -v "${resp__header}" ]]; then
 a__resp__header["${a__resp__header__file[${resp__header}]}"]="${!resp__header}"
    fi
done

else
    resp__status=404
fi

}

function \
qnetinfo__http__get__payload ()
{

local \
    file="${1:?argument-required}"
if [[ -f \
 "${file}" ]]; then

$CONCAT -- \
 "${file}"

fi

}

function \
qnetinfo__http__bad
{

    resp__status=${1:-500}

}

function \
qnetinfo__http ()
{

local \
    requ__type \
    requ__type__default='teapot'
declare -A \
 a__resp__header; local \
    resp__status
declare -r \
    HTTP__URI=?(+([![:space:]:/?#]):)?(//*([![:space:]/?#]))*([![:space:]?#])?(?*([![:space:]#]))?(#*([![:space:]])) \
    HTTP__VER='HTTP/1.'[01]
    HTTP__GET='GET' HEAD__HTTP__GET='HEAD'

 a__resp__header['Connection']='Close'

local \
  qnetinfo__http__get__file="${HTTPFILE:?httpfile}"

while IFS=$'\r\n' read recv; do
    if [[ -n "${recv}" ]]; then
        qnetinfo__printf \
'> %s' \
  "${recv}" >&2
    if [[ ! -v 'requ__type' ]]; then
        case "${recv}" in
            $HTTP__GET' '$HTTP__URI' '$HTTP__VER)
                requ__type=get ;;
      $HEAD__HTTP__GET' '$HTTP__URI' '$HTTP__VER)
                requ__type=get__head ;;
            *)
                requ__type=bad
        esac
        qnetinfo__printf \
'+ %s' \
  "${requ__type}" >&2
    fi
    else
        qnetinfo__prints \
'>' >&2
        break
    fi
done

if [[ ! -v requ__type ]]; then
    requ__type="${requ__type__default}"
fi

case "${requ__type}" in
    'get'|'get__'*) qnetinfo__http__get \
                 "${qnetinfo__http__get__file}" ;;
    'bad')          qnetinfo__http__bad 400 ;;
    'teapot')       qnetinfo__http__bad 418 ;;
    *)              qnetinfo__http__bad 500 ;;
esac

qnetinfo__printf \
'HTTP/1.1 %u' \
   "${resp__status}"
for resp__header in "${!a__resp__header[@]}"; do
qnetinfo__printf \
'%s: %s' \
   "${resp__header}" \
"${a__resp__header[${resp__header}]}"
done

qnetinfo__prints__crlf

if [[ "${resp__status}" -eq 200 ]]; then
case "${requ__type}" in
    'get')        qnetinfo__http__get__payload \
               "${qnetinfo__http__get__file}" ;;
esac
fi

}

qnetinfo__printf \
'+ note, press control-c to stop, will listen to %s ...' \
 "${HTTPPORT:-<unknown>}"

while true; do

qnetinfo__http__recv \
    <&5 | \
qnetinfo__http \
        | \
qnetinfo__http__send \
    >&5

done
