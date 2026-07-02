// Minimal shims for missing scoped Mapbox types referenced by the build
// These declaration stubs prevent TypeScript errors during `yarn prepare`/`bob build`.

declare module 'mapbox__point-geometry';
declare module '@mapbox/point-geometry';

// Generic fallback for any other missing modules used by generated types
declare module 'mapbox__*';
declare module '*.png' {
  const value: import('react-native').ImageSourcePropType;
  export default value;
}
