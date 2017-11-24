#!/bin/sh /bin/sh

# Этот скрипт включает только то, что нужно для поддержки стандарта кодирования

SH201708_SIGNALS="HUP INT QUIT ILL ABRT FPE SEGV PIPE ALRM TERM USR1 USR2" # Подходящие сигналы из POSIX.1-1990

# Не могу поставить sh201708_assert_cmd прямо сюда, т. к. эта функция ещё не определена

_SH201708_TESTS=":"

# Супер-лайт unit-тест фреймворк для UNIX shell. Без зависимости от cmp. Если всякие stdout содержат null bytes и прочее, то, скорее всего, всё сломается. Проблемы с \n в конце STDIN и STDOUT
sh201708_unit_test(){
	(
		set -e

		_sh201708_unit_test_usage(){
			printf -- '%s\n' "${0##*/}: sh201708_unit_test: usage: sh201708_unit_test [--] STDIN STDOUT empty|non-empty ok|fail COMMAND [ARG]..." >&2
			return 1
		}

		[ "$1" = "--" ] && shift

		[ $# -lt 5 ] && _sh201708_unit_test_usage

		IN="$1"

		EXPECTED_OUT="$2"

		EXPECTED_ERR="$3"
		[ "$EXPECTED_ERR" != "empty" ] && [ "$EXPECTED_ERR" != "non-empty" ] && _sh201708_unit_test_usage

		OK="$4"
		[ "$OK" != "ok" ] && [ "$OK" != "fail" ] && _sh201708_unit_test_usage

		shift
		shift
		shift
		shift

		REAL_OUT_FILE="$(mktemp /tmp/sh201708_unit_test-out-XXXXXX)"
		trap 'rm -- "$REAL_OUT_FILE"' EXIT
		trap 'exit 1' $SH201708_SIGNALS

		(
			REAL_ERR_FILE="$(mktemp /tmp/sh201708_unit_test-err-XXXXXX)"
			trap 'rm -- "$REAL_ERR_FILE"' EXIT
			trap 'exit 1' $SH201708_SIGNALS

			set +e

			(
				set -e
				printf -- '%s\n' "$IN" | "$@" > "$REAL_OUT_FILE" 2> "$REAL_ERR_FILE"
			)

			local STATUS=$?

			set -e

			local PASSED=true

			REAL_OUT="$(cat "$REAL_OUT_FILE")"
			[ "$EXPECTED_OUT" != "$REAL_OUT" ] && PASSED=false

			[ "$EXPECTED_ERR" = "empty" ] && [ -s "$REAL_ERR_FILE" ] && PASSED=false
			[ "$EXPECTED_ERR" = "non-empty" ] && ! [ -s "$REAL_ERR_FILE" ] && PASSED=false

			[ "$OK" = ok ] && [ "$STATUS" != 0 ] && PASSED=false
			[ "$OK" = fail ] && [ "$STATUS" = 0 ] && PASSED=false

			$PASSED && exit

			# У меня смутные воспоминания, что less плохо работает с файлами, которые не сбрасывают настройки цвета в конце строки
			printf -- '\033[1mCommand:\033[0m %s \033[1mInput:\033[0m\n' "$*"
			printf -- '%s\n' "$IN"
			printf -- '\033[1mReal output:\033[0m\n'
			cat -- "$REAL_OUT_FILE"
			printf -- '\033[1mReal error:\033[0m\n'
			cat -- "$REAL_ERR_FILE"
			printf -- '\033[1mReal status: %s\033[0m\n' "$STATUS"

			[ "$EXPECTED_OUT" != "$REAL_OUT" ] && printf -- '\033[1;31mExpected output:\033[0m\n' && printf -- '%s\n' "$EXPECTED_OUT"
			[ "$EXPECTED_ERR" = "empty" ] && [ -s "$REAL_ERR_FILE" ] && printf -- '\033[1;31mExpected error: empty\033[0m\n'
			[ "$EXPECTED_ERR" = "non-empty" ] && ! [ -s "$REAL_ERR_FILE" ] && printf -- '\033[1;31mExpected error: non-empty\033[0m\n'
			[ "$OK" = ok ] && [ "$STATUS" != 0 ] && printf -- '\033[31;1mExpected status: 0\033[0m\n'
			[ "$OK" = fail ] && [ "$STATUS" = 0 ] && printf -- '\033[31;1mExpected status: non-zero\033[0m\n'

			# We don't return non-zero here because it is probably "set -e" and we want to allow to run more unit tests
		)
	)
}

_sh201708_unit_test_simple(){
	[ "$1" = "--" ] && shift

	[ $# != 3 ] && printf -- '%s\n' "${0##*/}: _sh201708_unit_test_simple: usage: _sh201708_unit_test_simple FUNCTION OPERAND OUT" >&2 && return 1

	FUNCTION="$1"
	OPERAND="$2"
	OUT="$3"

	if [ "$OUT" = fail ]; then
		sh201708_unit_test -- "" ""     non-empty fail "$FUNCTION" -- "$OPERAND"
	else
		sh201708_unit_test -- "" "$OUT" empty     ok   "$FUNCTION" -- "$OPERAND"
	fi
}

# Пустое имя файла считается небезопасным, поэтому если исходное имя пустое, функция завершается с ошибкой
sh201708_to_safe(){
	[ "$1" = "--" ] && shift

	[ $# != 1 ] && printf -- '%s\n' "${0##*/}: sh201708_to_safe: usage: sh201708_to_safe FILE" >&2 && return 1

	U_FILE="$1"

	[ -z "$U_FILE" ] && printf -- '%s\n' "${0##*/}: sh201708_to_safe: file name is empty" >&2 && return 1

	if [ "${U_FILE#-}" = "$U_FILE" ]; then
		printf -- '%s\n' "$U_FILE"
	else
		printf -- '%s\n' "./$U_FILE"
	fi
}

sh201708_to_safe_TEST(){
	_sh201708_unit_test_simple sh201708_to_safe ""   fail
	_sh201708_unit_test_simple sh201708_to_safe "a"  "a"
	_sh201708_unit_test_simple sh201708_to_safe "-a" "./-a"
	_sh201708_unit_test_simple sh201708_to_safe "a-" "a-"
}

_SH201708_TESTS="${_SH201708_TESTS}; sh201708_to_safe_TEST"

# Цитата из документации к autoconf 2.69:
# Posix lets implementations treat leading // specially, but requires leading /// and beyond to be equivalent to /. Most Unix variants treat // like /. However, some treat // as a "super-root" that can provide access to files that are not otherwise reachable from /. The super-root tradition began with Apollo Domain/OS, which died out long ago, but unfortunately Cygwin has revived it.
# В связи с этим функции в этой библиотеке различают // и /, и при этом, как и требует POSIX (например, POSIX 2016), считают любое другое количество слешей эквивалентным одному слешу. Cygwin действительно различает / и // (я тестировал на Cygwin 2.3.1(0.291/5/3), во всяком случае именно это выдавала команда "uname -r"), а потому является живым примером концепта и площадкой для экспериментов. Cygwin считает ///, //// и так далее эквивалентными /, а также //.. - эквивалентным //

# Убирает концевые слеши, если операнд не состоит только из слешей
sh201708_strip_slashes(){
	(
		set -e

		[ "$1" = "--" ] && shift

		[ $# != 1 ] && printf -- '%s\n' "${0##*/}: sh201708_strip_slashes: usage: sh201708_strip_slashes FILE" >&2 && exit 1

		local E_FILE
		E_FILE="$(sh201708_to_safe "$1")"

		[ "$E_FILE" = "//" ] && printf -- '%s\n' "//" && exit 0

		while [ "${E_FILE%/}" != "$E_FILE" ]; do
			E_FILE="${E_FILE%/}"
		done

		[ -z "$E_FILE" ] && printf -- '%s\n' "/" && exit 0

		printf -- '%s\n' "$E_FILE"
	)
}

sh201708_strip_slashes_TEST(){
	_sh201708_unit_test_simple sh201708_strip_slashes ""                fail
	_sh201708_unit_test_simple sh201708_strip_slashes "/"               "/"
	_sh201708_unit_test_simple sh201708_strip_slashes "//"              "//"
	_sh201708_unit_test_simple sh201708_strip_slashes "///"             "/"
	_sh201708_unit_test_simple sh201708_strip_slashes "/a"              "/a"
	_sh201708_unit_test_simple sh201708_strip_slashes "/a/"             "/a"
	_sh201708_unit_test_simple sh201708_strip_slashes "/a//"            "/a"
	_sh201708_unit_test_simple sh201708_strip_slashes "a"               "a"
	_sh201708_unit_test_simple sh201708_strip_slashes "a/"              "a"
	_sh201708_unit_test_simple sh201708_strip_slashes "a//"             "a"
}

_SH201708_TESTS="${_SH201708_TESTS}; sh201708_strip_slashes_TEST"

# Если basename получился . или .., то он отметается. Т. к., возможно, скрипт хочет создать рядом с "/some/dir/$A" какой-нибудь "/some/dir/.$A.kate-swp" (и он не знает, что $A - это "."). Пытаться вычислить _настоящий_ basename в таких условиях тоже не нужно, т. к., возможно, скрипт хочет удалить папку "/some/dir/$A", не трогая при этом /some/dir, опять-таки, не зная, что $A - это "."
u_sh201708_basename(){
	(
		set -e

		[ "$1" = "--" ] && shift

		[ $# != 1 ] && printf -- '%s\n' "${0##*/}: u_sh201708_basename: usage: u_sh201708_basename FILE" >&2 && exit 1

		local U_ORIG_FILE="$1"
		local E_FILE
		E_FILE="$(sh201708_to_safe "$U_ORIG_FILE")"

		while [ "${E_FILE%/}" != "$E_FILE" ]; do
			E_FILE="${E_FILE%/}"
		done

		[ -z "$E_FILE" ] && printf -- '%s\n' "${0##*/}: u_sh201708_basename: $U_ORIG_FILE: file is / or //, it has no basename" >&2 && exit 1

		local U_BASENAME="${E_FILE##*/}"

		if [ "$U_BASENAME" = "." ] || [ "$U_BASENAME" = ".." ]; then
			printf -- '%s\n' "${0##*/}: u_sh201708_basename: $U_ORIG_FILE: basename is \".\" or \"..\", this is not allowed" >&2
			exit 1
		fi

		printf -- '%s\n' "$U_BASENAME"
	)
}

u_sh201708_basename_TEST(){
	_sh201708_unit_test_simple u_sh201708_basename ""         fail
	_sh201708_unit_test_simple u_sh201708_basename "/"        fail
	_sh201708_unit_test_simple u_sh201708_basename "//"       fail
	_sh201708_unit_test_simple u_sh201708_basename "///"      fail
	_sh201708_unit_test_simple u_sh201708_basename "."        fail
	_sh201708_unit_test_simple u_sh201708_basename ".."       fail
	_sh201708_unit_test_simple u_sh201708_basename "..."      "..."
	_sh201708_unit_test_simple u_sh201708_basename "a"        "a"
	_sh201708_unit_test_simple u_sh201708_basename "a/"       "a"
	_sh201708_unit_test_simple u_sh201708_basename "a/."      fail
	_sh201708_unit_test_simple u_sh201708_basename "a///"     "a"
	_sh201708_unit_test_simple u_sh201708_basename "a/b"      "b"
	_sh201708_unit_test_simple u_sh201708_basename "a/b/"     "b"
	_sh201708_unit_test_simple u_sh201708_basename "a/b/."    fail # Documented
	_sh201708_unit_test_simple u_sh201708_basename "/a"       "a"
	_sh201708_unit_test_simple u_sh201708_basename "/a/"      "a"
	_sh201708_unit_test_simple u_sh201708_basename "/a/b"     "b"
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/"    "b"
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/."   fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/./"  fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/./." fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/././" fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/././." fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/./././" fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/./././////" fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/./././////././///./////.////" fail
	_sh201708_unit_test_simple u_sh201708_basename "/./././////././///./////.////" fail
	_sh201708_unit_test_simple u_sh201708_basename "//./././////././///./////.////" fail
	_sh201708_unit_test_simple u_sh201708_basename "./././////././///./////.////" fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/.."  fail
	_sh201708_unit_test_simple u_sh201708_basename "/a/b/../" fail
	_sh201708_unit_test_simple u_sh201708_basename "//a"      "a"
	_sh201708_unit_test_simple u_sh201708_basename "///a"     "a"
	_sh201708_unit_test_simple u_sh201708_basename "/."       fail
	_sh201708_unit_test_simple u_sh201708_basename "//."      fail
	_sh201708_unit_test_simple u_sh201708_basename "///."     fail
	_sh201708_unit_test_simple u_sh201708_basename "/.."      fail
	_sh201708_unit_test_simple u_sh201708_basename "//.."     fail
	_sh201708_unit_test_simple u_sh201708_basename "///.."    fail
}

_SH201708_TESTS="${_SH201708_TESTS}; u_sh201708_basename_TEST"

# Наша задача - просто получить папку, в которой лежит файл. Необязательно, чтобы результат был особенно красив. Поэтому в ответ на .. мы просто выдаём ../.. . Можно было попытаться обратиться к реальной файловой системе и реально разрезолвить ../.. , но я считаю такое непозволительным в такой функции. Её выход должен зависеть только от входа
# u_sh201708_basename и sh201708_dirname обе не используют информацию, кроме как из исходной строки. Ну мало ли, может, мы давно сделали cd или chroot, или это файлы на каком-нибудь удалённом хосте и так далее. Это чисто строковые операции. У u_sh201708_basename и sh201708_dirname немного разная философия: u_sh201708_basename выдаёт ошибку на "a/b/.", а sh201708_dirname - не выдаёт. Причина такова: задача basename - вычислить "настоящий" basename, например, чтобы на его основе придумать имя lock-файла. Не используя при этом информацию кроме входной. Не пытаясь быть слишком умным, т. к. это не то, чего, скорее всего, хотел пользователь. Задача же dirname - вычислить имя папки. Любой ценой. В которой лежит этот файл. Всё
sh201708_dirname(){
	(
		set -e

		[ "$1" = "--" ] && shift

		[ $# != 1 ] && printf -- '%s\n' "${0##*/}: sh201708_dirname: usage: sh201708_dirname FILE" >&2 && exit 1

		local FILE
		FILE="$(sh201708_to_safe "$1")"

		while :; do
			FILE="$(sh201708_strip_slashes "$FILE")"

			if [ "$FILE" = "/" ] || [ "$FILE" = "//" ]; then
				printf -- '%s\n' "$FILE"
				exit 0
			fi

			if [ "${FILE##*/}" = ".." ]; then
				printf -- '%s\n' "$FILE/.."
				exit 0
			fi

			if [ "${FILE##*/}" != "." ]; then
				break
			fi

			if [ "$FILE" = "." ]; then
				printf -- '%s\n' ".."
				exit 0
			fi

			FILE="${FILE%.}"
		done

		if [ "${FILE##*/}" = "$FILE" ]; then
			printf -- '%s\n' "."
			exit 0
		fi

		sh201708_strip_slashes -- "${FILE%/*}/"
	)
}

sh201708_dirname_TEST(){
	_sh201708_unit_test_simple sh201708_dirname ""         fail
	_sh201708_unit_test_simple sh201708_dirname "/"        "/"
	_sh201708_unit_test_simple sh201708_dirname "//"       "//"
	_sh201708_unit_test_simple sh201708_dirname "///"      "/"
	_sh201708_unit_test_simple sh201708_dirname "."        ".."
	_sh201708_unit_test_simple sh201708_dirname ".."       "../.." # Documented
	_sh201708_unit_test_simple sh201708_dirname "..."      "."
	_sh201708_unit_test_simple sh201708_dirname "a"        "."
	_sh201708_unit_test_simple sh201708_dirname "a/"       "."
	_sh201708_unit_test_simple sh201708_dirname "a/."      "."
	_sh201708_unit_test_simple sh201708_dirname "a///"     "."
	_sh201708_unit_test_simple sh201708_dirname "a/b"      "a"
	_sh201708_unit_test_simple sh201708_dirname "a/b/"     "a"
	_sh201708_unit_test_simple sh201708_dirname "a/b/."    "a" # Documented
	_sh201708_unit_test_simple sh201708_dirname "/a"       "/"
	_sh201708_unit_test_simple sh201708_dirname "/a/"      "/"
	_sh201708_unit_test_simple sh201708_dirname "/a/b"     "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/"    "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/."   "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/./"  "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/./." "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/././" "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/././." "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/./././" "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/./././////" "/a"
	_sh201708_unit_test_simple sh201708_dirname "/a/b/./././////././///./////.////" "/a"
	_sh201708_unit_test_simple sh201708_dirname "/./././////././///./////.////" "/"
	_sh201708_unit_test_simple sh201708_dirname "//./././////././///./////.////" "//"
	_sh201708_unit_test_simple sh201708_dirname "./././////././///./////.////" ".."
	_sh201708_unit_test_simple sh201708_dirname "/a/b/.."  "/a/b/../.."
	_sh201708_unit_test_simple sh201708_dirname "/a/b/../" "/a/b/../.."
	_sh201708_unit_test_simple sh201708_dirname "//a"      "//"
	_sh201708_unit_test_simple sh201708_dirname "///a"     "/"
	_sh201708_unit_test_simple sh201708_dirname "/."       "/"
	_sh201708_unit_test_simple sh201708_dirname "//."      "//"
	_sh201708_unit_test_simple sh201708_dirname "///."     "/"
	_sh201708_unit_test_simple sh201708_dirname "/.."      "/../.."
	_sh201708_unit_test_simple sh201708_dirname "//.."     "//../.."
	_sh201708_unit_test_simple sh201708_dirname "///.."    "///../.."
}

_SH201708_TESTS="${_SH201708_TESTS}; sh201708_dirname_TEST"

# Эта функция написана с учётом того, что она может быть вызывана напрямую из shell library, а та - из интерактивного shell, поэтому эта функция не делает exit
# Позволяет проверить в том числе наличие builtin'ов
sh201708_assert_cmd(){
	[ "$1" = "--" ] && shift

	[ $# != 1 ] && printf -- '%s\n' "${0##*/}: sh201708_assert_cmd: usage: sh201708_assert_cmd COMMAND" >&2 && return 1

	local COMMAND="$1"

	[ "${COMMAND#-}" != "$COMMAND" ] && printf -- '%s\n' "${0##*/}: sh201708_assert_cmd: $COMMAND: command begins with dash, we cannot check it" >&2 && return 1

	if ! type "$COMMAND" > /dev/null 2>&1; then
		printf -- '%s\n' "${0##*/}: sh201708_assert_cmd: $COMMAND: command not found" >&2
		return 1
	fi
}

sh201708_assert_cmd_TEST(){
	_sh201708_unit_test_simple sh201708_assert_cmd "" fail
	_sh201708_unit_test_simple sh201708_assert_cmd "-" fail
	_sh201708_unit_test_simple sh201708_assert_cmd "--" fail
	_sh201708_unit_test_simple sh201708_assert_cmd "-a" fail
	_sh201708_unit_test_simple sh201708_assert_cmd ":" ""
	_sh201708_unit_test_simple sh201708_assert_cmd "rm" ""
}

_SH201708_TESTS="${_SH201708_TESTS}; sh201708_assert_cmd_TEST"

sh201708_TEST(){
	eval " ${_SH201708_TESTS}"
}

sh201708_assert_cmd mktemp
