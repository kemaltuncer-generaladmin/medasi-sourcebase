{{flutter_js}}
{{flutter_build_config}}

const sourcebaseBuildVersion = window.SOURCEBASE_BUILD_VERSION || '20260516-1338';

if (window._flutter?.buildConfig?.builds) {
  for (const build of window._flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      build.mainJsPath = `${build.mainJsPath}?v=${sourcebaseBuildVersion}`;
    }
  }
}

_flutter.loader.load();
