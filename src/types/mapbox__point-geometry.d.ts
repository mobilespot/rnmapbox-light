declare module 'mapbox__point-geometry' {
  export interface Point {
    x: number;
    y: number;
  }

  export interface PointLike {
    x: number;
    y: number;
  }

  export class PointGeometry {
    constructor(x?: number, y?: number);
    x: number;
    y: number;
    clone(): PointGeometry;
    add(other: PointLike): PointGeometry;
    sub(other: PointLike): PointGeometry;
    multByScalar(factor: number): PointGeometry;
  }
}

declare module '@mapbox/point-geometry' {
  export * from 'mapbox__point-geometry';
}
