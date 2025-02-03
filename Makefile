.PHONY: build publish clean

build:
	dotnet build

publish:
	dotnet publish -c Release -o publish -p:PublishReadyToRun=true -p:PublishSingleFile=true --self-contained true -p:IncludeNativeLibrariesForSelfExtract=true

clean:
	dotnet clean