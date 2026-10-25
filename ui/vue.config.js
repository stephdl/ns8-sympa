module.exports = {
  css: {
    loaderOptions: {
      sass: {
        sassOptions: {
          silenceDeprecations: ["import", "global-builtin", "color-functions", "if-function", "legacy-js-api"],
        },
      },
    },
  },
  publicPath: "./",
  // The core launcher loads the logo by file name: never inline it
  chainWebpack: (config) => {
    config.module
      .rule("images")
      .use("url-loader")
      .tap((options) => Object.assign(options, { limit: -1 }));
  },
  configureWebpack: {
    optimization: {
      splitChunks: {
        maxSize: 500000,
      },
    },
  },
};
