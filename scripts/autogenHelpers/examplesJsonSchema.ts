export type ExampleMetadata = {
  title: string;
  tags: string[];
  docs: string;
};

export type ExampleGroupMetadata = {
  title: string;
};

export type Example = {
  name: string;
  metadata: ExampleMetadata;
  fullPath: string;
  relPath: string;
};

export type ExampleGroup = {
  groupName: string;
  metadata: ExampleGroupMetadata;
  examples: Example[];
};

export type Examples = ExampleGroup[];
