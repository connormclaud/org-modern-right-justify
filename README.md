# Org Modern Right Justify

Minor visual enhancements for Org mode, particularly pixel perfect right justify for users of `org-modern` agenda view. This package currently provides:

1.  **Right-Aligned Tags in Agenda:** Automatically right-aligns the first encountered (typically rightmost) tag group on each line in Org Agenda buffers that are processed by `org-modern`. This uses your `org-agenda-tags-column` setting as a reference but ultimately right-aligns the tags using a display property.

## Rationale

- The tag alignment aims to provide a cleaner, more table-like appearance in the agenda by ensuring tags are neatly justified to the right.
- `Org-modern` maintainer rejects to support right justify in the scope of his project: https://github.com/minad/org-modern/pull/209

## Installation

It is recommended to install this package using a package manager like `straight.el` with `use-package`.

### Prerequisites

-   Emacs 30.1 or later.
-   Org mode 9.8 or later.
-   `org-modern` (e.g., version 1.7 or later).

### Using `use-package` with `straight.el` (Recommended)

Add the following to your Emacs configuration file (e.g., `init.el`):
```
(use-package org-modern-right-justify
  :straight (:host github :repo "connormclaud/org-modern-right-justify")
  :after (org-modern org-habit) ; Ensures advised functions are loaded
  :config
  (org-modern-right-justify-activate))
```

### Manual Installation

1.  Download `org-modern-right-justify.el`.
2.  Place it in a directory included in your Emacs `load-path`.
3.  Add the following to your Emacs configuration:

(require 'org-modern-right-justify)
(org-modern-right-justify-activate)

## Usage

Once installed and activated (typically via the `:config` block in `use-package` or by manually calling `org-modern-right-justify-activate`), the enhancements will apply automatically once you rebuild your agenda:
-   Tags will be right-aligned in agenda views generated with `org-modern`.

You can manually deactivate the enhancements by calling `(org-modern-right-justify-deactivate)`.

## How Tag Alignment Works

The tag alignment function `org-modern-right-justify--align-tags` is applied `:after` `org-modern-agenda` modifies the agenda buffer. For each relevant line:

1.  It searches for Org mode tags (using `org-tag-group-re`).
2.  It determines a target column based on your `org-agenda-tags-column` variable.
    * If `org-agenda-tags-column` is `'auto` or negative, it's calculated relative to the right edge of the window.
    * If positive, that value is used as a reference. (I haven't tested it with positive values)
3.  It removes any existing whitespace immediately preceding the tags on their line.
4.  It inserts a calculated amount of leading padding space. 
5.  Crucially, it then inserts a special space character just before the tags. This space is `propertize`d with a `display` property: `'(space :align-to (- right (TAG_PIXEL_WIDTH)))`.
    * This `display` property instructs Emacs to render that space such that the tags *following* it will have their right edge aligned `TAG_PIXEL_WIDTH` pixels away from the right margin of the display area.
    * This results in the tags being precisely right-aligned, taking into account the actual pixel width of the tags, which is important for proportional fonts.

## Contributing

Contributions, bug reports, and suggestions are welcome! Please open an issue or pull request on the GitHub repository.

## License

This package is licensed under the GPL version 3. See the `LICENSE` file for details.
