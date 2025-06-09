module.exports = {
  root: true,
  env: {
    es2020: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parserOptions: {
    ecmaVersion: 2020,
  },
  rules: {
    "quotes": ["error", "double"],
    "require-jsdoc": 0,
    "quote-props": "off",
    "max-len": "off",
    "valid-jsdoc": 0, // Bu satırı ekleyin
  },
};
