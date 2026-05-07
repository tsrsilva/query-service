@REM materializer launcher script
@REM
@REM Environment:
@REM JAVA_HOME - location of a JDK home dir (optional if java on path)
@REM CFG_OPTS  - JVM options (optional)
@REM Configuration:
@REM MATERIALIZER_config.txt found in the MATERIALIZER_HOME.
@setlocal enabledelayedexpansion
@setlocal enableextensions

@echo off


if "%MATERIALIZER_HOME%"=="" (
  set "APP_HOME=%~dp0\\.."

  rem Also set the old env name for backwards compatibility
  set "MATERIALIZER_HOME=%~dp0\\.."
) else (
  set "APP_HOME=%MATERIALIZER_HOME%"
)

set "APP_LIB_DIR=%APP_HOME%\lib\"

rem Detect if we were double clicked, although theoretically A user could
rem manually run cmd /c
for %%x in (!cmdcmdline!) do if %%~x==/c set DOUBLECLICKED=1

rem FIRST we load the config file of extra options.
set "CFG_FILE=%APP_HOME%\MATERIALIZER_config.txt"
set CFG_OPTS=
call :parse_config "%CFG_FILE%" CFG_OPTS

rem We use the value of the JAVA_OPTS environment variable if defined, rather than the config.
set _JAVA_OPTS=%JAVA_OPTS%
if "!_JAVA_OPTS!"=="" set _JAVA_OPTS=!CFG_OPTS!

rem We keep in _JAVA_PARAMS all -J-prefixed and -D-prefixed arguments
rem "-J" is stripped, "-D" is left as is, and everything is appended to JAVA_OPTS
set _JAVA_PARAMS=
set _APP_ARGS=

set "APP_CLASSPATH=%APP_LIB_DIR%\org.renci.materializer-0.2.7.jar;%APP_LIB_DIR%\org.scala-lang.scala-library-2.13.10.jar;%APP_LIB_DIR%\dev.zio.zio_2.13-2.0.5.jar;%APP_LIB_DIR%\dev.zio.zio-streams_2.13-2.0.5.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-zio_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-http4s-server-zio_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-swagger-ui-bundle_2.13-1.2.3.jar;%APP_LIB_DIR%\dev.zio.zio-interop-cats_2.13-3.3.0.jar;%APP_LIB_DIR%\org.http4s.http4s-blaze-server_2.13-0.23.11.jar;%APP_LIB_DIR%\org.geneontology.whelk-owlapi_2.13-1.1.2.jar;%APP_LIB_DIR%\org.geneontology.arachne_2.13-1.3.jar;%APP_LIB_DIR%\com.outr.scribe-slf4j_2.13-2.8.3.jar;%APP_LIB_DIR%\com.github.alexarchambault.case-app_2.13-2.0.6.jar;%APP_LIB_DIR%\dev.zio.zio-internal-macros_2.13-2.0.5.jar;%APP_LIB_DIR%\dev.zio.zio-stacktracer_2.13-2.0.5.jar;%APP_LIB_DIR%\dev.zio.izumi-reflect_2.13-2.2.2.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-core_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.shared.zio_2.13-1.3.10.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-http4s-server_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-swagger-ui_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-openapi-docs_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.openapi-circe-yaml_2.13-0.3.1.jar;%APP_LIB_DIR%\org.http4s.http4s-blaze-core_2.13-0.23.11.jar;%APP_LIB_DIR%\org.http4s.http4s-server_2.13-0.23.16.jar;%APP_LIB_DIR%\org.geneontology.whelk_2.13-1.1.2.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-distribution-4.5.22.jar;%APP_LIB_DIR%\org.phenoscape.scowl_2.13-1.4.1.jar;%APP_LIB_DIR%\org.scalaz.scalaz-core_2.13-7.3.7.jar;%APP_LIB_DIR%\org.geneontology.owl-to-rules_2.13-0.3.8.jar;%APP_LIB_DIR%\org.backuity.clist.clist-core_2.13-3.5.1.jar;%APP_LIB_DIR%\com.outr.scribe_2.13-2.8.3.jar;%APP_LIB_DIR%\org.slf4j.slf4j-api-1.7.36.jar;%APP_LIB_DIR%\com.github.alexarchambault.case-app-annotations_2.13-2.0.6.jar;%APP_LIB_DIR%\com.github.alexarchambault.case-app-util_2.13-2.0.6.jar;%APP_LIB_DIR%\org.apache.jena.jena-shacl-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-shex-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-tdb-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-tdb2-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-rdfconnection-4.6.1.jar;%APP_LIB_DIR%\dev.zio.izumi-reflect-thirdparty-boopickle-shaded_2.13-2.2.2.jar;%APP_LIB_DIR%\com.softwaremill.sttp.model.core_2.13-1.5.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.shared.core_2.13-1.3.10.jar;%APP_LIB_DIR%\com.softwaremill.sttp.shared.ws_2.13-1.3.10.jar;%APP_LIB_DIR%\com.softwaremill.magnolia1_2.magnolia_2.13-1.1.2.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-server_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-cats_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.shared.fs2_2.13-1.3.10.jar;%APP_LIB_DIR%\org.webjars.swagger-ui-4.15.5.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-apispec-docs_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.sttp.tapir.tapir-enumeratum_2.13-1.2.3.jar;%APP_LIB_DIR%\com.softwaremill.quicklens.quicklens_2.13-1.9.0.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.openapi-model_2.13-0.3.1.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.openapi-circe_2.13-0.3.1.jar;%APP_LIB_DIR%\io.circe.circe-yaml_2.13-0.14.1.jar;%APP_LIB_DIR%\org.http4s.http4s-core_2.13-0.23.16.jar;%APP_LIB_DIR%\org.http4s.blaze-http_2.13-0.15.3.jar;%APP_LIB_DIR%\org.geneontology.archimedes_2.13-0.1.1.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-compatibility-4.5.22.jar;%APP_LIB_DIR%\com.fasterxml.jackson.core.jackson-core-2.13.3.jar;%APP_LIB_DIR%\com.fasterxml.jackson.core.jackson-databind-2.13.3.jar;%APP_LIB_DIR%\com.fasterxml.jackson.core.jackson-annotations-2.13.3.jar;%APP_LIB_DIR%\org.tukaani.xz-1.6.jar;%APP_LIB_DIR%\org.slf4j.jcl-over-slf4j-1.7.36.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-model-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-api-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-languages-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-datatypes-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-binary-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-n3-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-nquads-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-ntriples-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-rdfjson-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-jsonld-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-rdfxml-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-trix-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-turtle-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-rio-trig-2.4.2.jar;%APP_LIB_DIR%\org.eclipse.rdf4j.rdf4j-util-2.4.2.jar;%APP_LIB_DIR%\com.github.jsonld-java.jsonld-java-0.13.4.jar;%APP_LIB_DIR%\com.github.vsonnier.hppcrt-0.7.5.jar;%APP_LIB_DIR%\com.google.guava.guava-18.0.jar;%APP_LIB_DIR%\com.google.code.findbugs.jsr305-3.0.1.jar;%APP_LIB_DIR%\commons-io.commons-io-2.11.0.jar;%APP_LIB_DIR%\com.typesafe.scala-logging.scala-logging_2.13-3.9.4.jar;%APP_LIB_DIR%\org.scala-lang.modules.scala-parallel-collections_2.13-1.0.4.jar;%APP_LIB_DIR%\com.outr.scribe-macros_2.13-2.8.3.jar;%APP_LIB_DIR%\com.outr.perfolation_2.13-1.2.0.jar;%APP_LIB_DIR%\com.chuusai.shapeless_2.13-2.3.10.jar;%APP_LIB_DIR%\org.apache.jena.jena-arq-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-dboe-storage-4.6.1.jar;%APP_LIB_DIR%\org.typelevel.cats-core_2.13-2.9.0.jar;%APP_LIB_DIR%\org.typelevel.cats-effect_2.13-3.4.1.jar;%APP_LIB_DIR%\co.fs2.fs2-core_2.13-3.3.0.jar;%APP_LIB_DIR%\co.fs2.fs2-io_2.13-3.3.0.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.asyncapi-model_2.13-0.3.1.jar;%APP_LIB_DIR%\com.beachape.enumeratum_2.13-1.7.0.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.apispec-model_2.13-0.3.1.jar;%APP_LIB_DIR%\com.softwaremill.sttp.apispec.jsonschema-circe_2.13-0.3.1.jar;%APP_LIB_DIR%\io.circe.circe-core_2.13-0.14.3.jar;%APP_LIB_DIR%\org.yaml.snakeyaml-1.28.jar;%APP_LIB_DIR%\org.typelevel.case-insensitive_2.13-1.3.0.jar;%APP_LIB_DIR%\org.typelevel.cats-effect-std_2.13-3.4.1.jar;%APP_LIB_DIR%\org.typelevel.cats-parse_2.13-0.3.8.jar;%APP_LIB_DIR%\org.http4s.http4s-crypto_2.13-0.2.4.jar;%APP_LIB_DIR%\com.comcast.ip4s-core_2.13-3.2.0.jar;%APP_LIB_DIR%\org.typelevel.literally_2.13-1.1.0.jar;%APP_LIB_DIR%\org.scodec.scodec-bits_2.13-1.1.34.jar;%APP_LIB_DIR%\org.typelevel.vault_2.13-3.3.0.jar;%APP_LIB_DIR%\org.log4s.log4s_2.13-1.10.0.jar;%APP_LIB_DIR%\org.typelevel.log4cats-slf4j_2.13-2.5.0.jar;%APP_LIB_DIR%\org.http4s.blaze-core_2.13-0.15.3.jar;%APP_LIB_DIR%\com.twitter.hpack-1.0.2.jar;%APP_LIB_DIR%\com.lihaoyi.fastparse_2.13-2.3.1.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-apibinding-4.5.22.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpclient-4.5.13.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpclient-cache-4.5.13.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpclient-osgi-4.5.13.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpcore-osgi-4.4.14.jar;%APP_LIB_DIR%\org.scala-lang.scala-reflect-2.13.10.jar;%APP_LIB_DIR%\org.scala-lang.modules.scala-collection-compat_2.13-2.8.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-core-4.6.1.jar;%APP_LIB_DIR%\com.google.code.gson.gson-2.9.1.jar;%APP_LIB_DIR%\com.apicatalog.titanium-json-ld-1.3.1.jar;%APP_LIB_DIR%\org.glassfish.jakarta.json-2.0.1.jar;%APP_LIB_DIR%\com.google.protobuf.protobuf-java-3.21.4.jar;%APP_LIB_DIR%\org.apache.thrift.libthrift-0.16.0.jar;%APP_LIB_DIR%\org.apache.commons.commons-lang3-3.12.0.jar;%APP_LIB_DIR%\org.apache.jena.jena-dboe-trans-data-4.6.1.jar;%APP_LIB_DIR%\org.typelevel.cats-kernel_2.13-2.9.0.jar;%APP_LIB_DIR%\org.typelevel.cats-effect-kernel_2.13-3.4.1.jar;%APP_LIB_DIR%\com.beachape.enumeratum-macros_2.13-1.6.1.jar;%APP_LIB_DIR%\io.circe.circe-parser_2.13-0.14.3.jar;%APP_LIB_DIR%\io.circe.circe-generic_2.13-0.14.3.jar;%APP_LIB_DIR%\io.circe.circe-numbers_2.13-0.14.3.jar;%APP_LIB_DIR%\org.typelevel.log4cats-core_2.13-2.5.0.jar;%APP_LIB_DIR%\com.lihaoyi.sourcecode_2.13-0.2.3.jar;%APP_LIB_DIR%\com.lihaoyi.geny_2.13-0.6.5.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-api-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-impl-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-parsers-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-oboformat-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-tools-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-fixers-4.5.22.jar;%APP_LIB_DIR%\net.sourceforge.owlapi.owlapi-rio-4.5.22.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpcore-4.4.14.jar;%APP_LIB_DIR%\commons-codec.commons-codec-1.15.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpmime-4.5.13.jar;%APP_LIB_DIR%\org.apache.httpcomponents.fluent-hc-4.5.13.jar;%APP_LIB_DIR%\org.apache.httpcomponents.httpcore-nio-4.4.14.jar;%APP_LIB_DIR%\org.apache.jena.jena-base-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-iri-4.6.1.jar;%APP_LIB_DIR%\commons-cli.commons-cli-1.5.0.jar;%APP_LIB_DIR%\javax.annotation.javax.annotation-api-1.3.2.jar;%APP_LIB_DIR%\org.apache.jena.jena-dboe-transaction-4.6.1.jar;%APP_LIB_DIR%\org.apache.jena.jena-dboe-index-4.6.1.jar;%APP_LIB_DIR%\io.circe.circe-jawn_2.13-0.14.3.jar;%APP_LIB_DIR%\com.github.ben-manes.caffeine.caffeine-2.8.6.jar;%APP_LIB_DIR%\javax.inject.javax.inject-1.jar;%APP_LIB_DIR%\org.apache.jena.jena-shaded-guava-4.6.1.jar;%APP_LIB_DIR%\org.apache.commons.commons-csv-1.9.0.jar;%APP_LIB_DIR%\org.apache.commons.commons-compress-1.21.jar;%APP_LIB_DIR%\com.github.andrewoma.dexx.collection-0.7.jar;%APP_LIB_DIR%\commons-logging.commons-logging-1.2.jar;%APP_LIB_DIR%\org.apache.jena.jena-dboe-base-4.6.1.jar;%APP_LIB_DIR%\org.typelevel.jawn-parser_2.13-1.4.0.jar;%APP_LIB_DIR%\org.checkerframework.checker-qual-3.7.0.jar;%APP_LIB_DIR%\com.google.errorprone.error_prone_annotations-2.4.0.jar"
set "APP_MAIN_CLASS=org.renci.materializer.Main"
set "SCRIPT_CONF_FILE=%APP_HOME%\conf\application.ini"

rem Bundled JRE has priority over standard environment variables
if defined BUNDLED_JVM (
  set "_JAVACMD=%BUNDLED_JVM%\bin\java.exe"
) else (
  if "%JAVACMD%" neq "" (
    set "_JAVACMD=%JAVACMD%"
  ) else (
    if "%JAVA_HOME%" neq "" (
      if exist "%JAVA_HOME%\bin\java.exe" set "_JAVACMD=%JAVA_HOME%\bin\java.exe"
    )
  )
)

if "%_JAVACMD%"=="" set _JAVACMD=java

rem Detect if this java is ok to use.
for /F %%j in ('"%_JAVACMD%" -version  2^>^&1') do (
  if %%~j==java set JAVAINSTALLED=1
  if %%~j==openjdk set JAVAINSTALLED=1
)

rem BAT has no logical or, so we do it OLD SCHOOL! Oppan Redmond Style
set JAVAOK=true
if not defined JAVAINSTALLED set JAVAOK=false

if "%JAVAOK%"=="false" (
  echo.
  echo A Java JDK is not installed or can't be found.
  if not "%JAVA_HOME%"=="" (
    echo JAVA_HOME = "%JAVA_HOME%"
  )
  echo.
  echo Please go to
  echo   http://www.oracle.com/technetwork/java/javase/downloads/index.html
  echo and download a valid Java JDK and install before running materializer.
  echo.
  echo If you think this message is in error, please check
  echo your environment variables to see if "java.exe" and "javac.exe" are
  echo available via JAVA_HOME or PATH.
  echo.
  if defined DOUBLECLICKED pause
  exit /B 1
)

rem if configuration files exist, prepend their contents to the script arguments so it can be processed by this runner
call :parse_config "%SCRIPT_CONF_FILE%" SCRIPT_CONF_ARGS

call :process_args %SCRIPT_CONF_ARGS% %%*

set _JAVA_OPTS=!_JAVA_OPTS! !_JAVA_PARAMS!

if defined CUSTOM_MAIN_CLASS (
    set MAIN_CLASS=!CUSTOM_MAIN_CLASS!
) else (
    set MAIN_CLASS=!APP_MAIN_CLASS!
)

rem Call the application and pass all arguments unchanged.
"%_JAVACMD%" !_JAVA_OPTS! !MATERIALIZER_OPTS! -cp "%APP_CLASSPATH%" %MAIN_CLASS% !_APP_ARGS!

@endlocal

exit /B %ERRORLEVEL%


rem Loads a configuration file full of default command line options for this script.
rem First argument is the path to the config file.
rem Second argument is the name of the environment variable to write to.
:parse_config
  set _PARSE_FILE=%~1
  set _PARSE_OUT=
  if exist "%_PARSE_FILE%" (
    FOR /F "tokens=* eol=# usebackq delims=" %%i IN ("%_PARSE_FILE%") DO (
      set _PARSE_OUT=!_PARSE_OUT! %%i
    )
  )
  set %2=!_PARSE_OUT!
exit /B 0


:add_java
  set _JAVA_PARAMS=!_JAVA_PARAMS! %*
exit /B 0


:add_app
  set _APP_ARGS=!_APP_ARGS! %*
exit /B 0


rem Processes incoming arguments and places them in appropriate global variables
:process_args
  :param_loop
  call set _PARAM1=%%1
  set "_TEST_PARAM=%~1"

  if ["!_PARAM1!"]==[""] goto param_afterloop


  rem ignore arguments that do not start with '-'
  if "%_TEST_PARAM:~0,1%"=="-" goto param_java_check
  set _APP_ARGS=!_APP_ARGS! !_PARAM1!
  shift
  goto param_loop

  :param_java_check
  if "!_TEST_PARAM:~0,2!"=="-J" (
    rem strip -J prefix
    set _JAVA_PARAMS=!_JAVA_PARAMS! !_TEST_PARAM:~2!
    shift
    goto param_loop
  )

  if "!_TEST_PARAM:~0,2!"=="-D" (
    rem test if this was double-quoted property "-Dprop=42"
    for /F "delims== tokens=1,*" %%G in ("!_TEST_PARAM!") DO (
      if not ["%%H"] == [""] (
        set _JAVA_PARAMS=!_JAVA_PARAMS! !_PARAM1!
      ) else if [%2] neq [] (
        rem it was a normal property: -Dprop=42 or -Drop="42"
        call set _PARAM1=%%1=%%2
        set _JAVA_PARAMS=!_JAVA_PARAMS! !_PARAM1!
        shift
      )
    )
  ) else (
    if "!_TEST_PARAM!"=="-main" (
      call set CUSTOM_MAIN_CLASS=%%2
      shift
    ) else (
      set _APP_ARGS=!_APP_ARGS! !_PARAM1!
    )
  )
  shift
  goto param_loop
  :param_afterloop

exit /B 0
