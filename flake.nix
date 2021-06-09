{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    unstable.url =
      "github:PeterZainzinger/nixpkgs/fd63cdd1dc9ae6a0126b080fd8c9f009711386b0";
  };
  description = "flutter setup";
  outputs = { self, nixpkgs, flake-utils, unstable }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        #pkgs = nixpkgs.legacyPackages.${system};
        pkgs = (import unstable {
          system = system;
          config = {
            allowUnfree = true;
            # permittedInsecurePackages = [ "openssl-1.0.2u" ];
            android_sdk.accept_license = true;
          };
        });
        android_10 = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "30" ];
          abiVersions = [ "x86" "x86_64" ];
          includeExtras = [ "extras;android;m2repository" ];
          buildToolsVersions = [ "29.0.2" "30.0.2" ];
          platformToolsVersion = "30.0.4";
          toolsVersion = "26.1.1";
          includeNDK = true;
        };
        #android_pkg = pkgs.androidenv.androidPkgs_9_0;
        android_pkg = android_10;
        androidsdk = android_pkg.androidsdk.overrideAttrs (oldAttrs: {
          installPhase = oldAttrs.installPhase + ''
            mkdir -p "$out/libexec/android-sdk/licenses";
            echo -e "\n8933bad161af4178b1185d1a37fbf41ea5269c55" > "$out/libexec/android-sdk/licenses/android-sdk-license";
            echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > "$out/libexec/android-sdk/licenses/android-sdk-preview-license"; '';
        });
        platformTools = android_pkg.platform-tools;
        myjava = pkgs.jetbrains.jdk;
        common = with pkgs; [ myjava androidsdk platformTools flutter python ];
        setupScript = ''
          export JAVA_HOME=${myjava}
          export ANDROID_HOME=${androidsdk}/libexec/android-sdk
          export ANDROID_SDK=${androidsdk}/libexec/android-sdk
          export ANDROID_NDK=${androidsdk}/libexec/android-sdk/ndk-bundle
          echo "sdk.dir=${androidsdk}/libexec/android-sdk" > local.properties
          echo "android.aapt2FromMavenOverride=${androidsdk}/libexec/android-sdk/build-tools/30.0.2/aapt2" >> local.properties
          export FLUTTER_SDK=${pkgs.flutter.unwrapped}
          export GRADLE_OPTS=-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidsdk}/libexec/android-sdk/build-tools/30.0.2/aapt2

        '';
        tools_state = builtins.toJSON {
          "is-bot" = false;
          "redisplay-welcome-message" = false;
        };
      in {

        devShell = pkgs.mkShell {
          buildInputs = common;
          shellHook = setupScript;
        };
        defaultPackage = pkgs.stdenv.mkDerivation {
          name = "flutter-sample-app";
          src = ./.;
          buildInputs = common;
          buildPhase = ''
            ${setupScript}
            echo ${tools_state} > .flutter_tool_state
            export HOME=$(pwd)
            export GRADLE_USER_HOME=$(pwd)
            export ANDROID_SDK_HOME=`pwd` 
            flutter pub get
            flutter build apk
          '';
          installPhase = ''
            mkdir -p "$out/bin"
            ls -lah ./build/app/outputs/flutter-apk/app-release.apk
            cp ./build/app/outputs/flutter-apk/app-release.apk $out/bin
          '';
        };

      });
}

