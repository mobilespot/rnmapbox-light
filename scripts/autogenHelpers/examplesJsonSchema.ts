export type ExampleGroupMetadata = {
  title: string;
};

export type Example = {
  name: string;
  fullPath: string;
  relPath: string;
};

export type ExampleGroup = {
  groupName: string;
  metadata: ExampleGroupMetadata;
  examples: Example[];
};

export type Examples = ExampleGroup[];
