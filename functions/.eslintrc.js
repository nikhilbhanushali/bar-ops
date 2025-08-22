module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: { ecmaVersion: 2020, sourceType: 'module' },
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier'
  ],
  rules: {
    'linebreak-style': 'off',
    'require-jsdoc': 'off',
    'max-len': ['warn', { code: 100, ignoreUrls: true, ignoreStrings: true }],
    'object-curly-spacing': ['error', 'always'],
    '@typescript-eslint/no-explicit-any': 'off'
  }
};
