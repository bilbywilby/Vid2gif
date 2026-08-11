@ECHO OFF

pushd %~dp0

%SPHINXBUILD% >NUL 2>NUL
if errorlevel 9009 (
	echo.
	echo.The 'sphinx-build' command was not found. Make sure you have Sphinx
	echo.installed, then add the executable path to your PATH.
	echo.
	exit /b 1
)

set SPHINXBUILD=sphinx-build
set SOURCEDIR=.
set BUILDDIR=_build

%SPHINXBUILD% -M %1 %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
goto end

:end
popd
