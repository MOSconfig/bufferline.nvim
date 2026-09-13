# Features

- Colours derived from the colorscheme where possible.
- Sort buffers by `extension`, `directory`, or a custom compare function.
- Configuration via Lua functions for greater customization.

See also: [Multiline Buffer Tabs](Multiline-Buffer-Tabs).

## Alternate styling

### Slanted tabs

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

**NOTE**: some terminals require special characters to be padded, so set the style to
`padded_slant` if the appearance isn't right in your terminal emulator. Results vary by
terminal emulator and this style might not work everywhere.

### Sloped tabs

![sloped tabs](https://user-images.githubusercontent.com/22454918/220115787-0ba2264f-1cf5-4f18-a322-7c7cfa3d8f42.png)

See `:help bufferline-styling`.

## Hover events

**NOTE**: only available for Neovim 0.8+. Not supported with
[multiline](Multiline-Buffer-Tabs).

![hover-event-preview](https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif)

See `:help bufferline-hover-events`.

## Underline indicator

<img width="1355" alt="Screen Shot 2022-08-22 at 09 14 24" src="https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png">

Your mileage will vary based on your terminal emulator. The screenshot above was achieved
using kitty nightly (as of August 2022), with increased underline thickness and an
increased underline position so it sits further from the text.

## Tabpages

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

Set the `mode` option to `tabs` to show only tabpages. This turns the bufferline into a
tabline with many of the same features and styling, but not all:

- Sorting doesn't work yet, as that needs to be thought through.
- Grouping doesn't work yet, for the same reason.

`mode = "tabs"` is not supported with multiline.

## LSP indicators

![LSP Indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

Setting `diagnostics = "nvim_lsp" | "coc"` adds an indicator for any buffer with errors,
so you can tell at a glance which buffers are affected.

Customise the appearance of the count with a function:

```lua
--- count is an integer representing total count of errors
--- level is a string "error" | "warning"
--- diagnostics_dict is a dictionary from error level ("error", "warning" or "info") to number of errors for each level.
--- this should return a string
--- Don't get too fancy as this function will be executed a lot
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local icon = level:match("error") and " " or " "
  return " " .. icon .. count
end
```

![diagnostics_indicator](https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png)

```lua
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local s = " "
  for e, n in pairs(diagnostics_dict) do
    local sym = e == "error" and " "
      or (e == "warning" and " " or " ")
    s = s .. n .. sym
  end
  return s
end
```

Indicators can be reported conditionally, based on buffer context. For instance, disable
them for the current buffer and show them only for other buffers:

```lua
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  if context.buffer:current() then
    return ''
  end

  return ''
end
```

![current](https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg)
![visible](https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg)

The first bufferline shows `diagnostic.lua` as the `current` buffer. It has LSP reported
errors, but they don't show up. The second shows `500-nvim-bufferline.lua` as `current`;
because the 'faulty' `diagnostic.lua` buffer transitioned from `current` to `visible`, its
indicator now appears.

Change the filename highlighting for error states via `:help bufferline-highlights`.

## Groups

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

Groups visualize related buffers in clusters and let you operate on them together — for
example, clicking the group indicator hides all its buffers. Partly inspired by Chrome's
tabs and centaur-tabs' groups.

See `:help bufferline-groups`.

## Sidebar offsets

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

See `:help bufferline-sidebar-offset`. Offsets apply to the native tabline only;
multiline uses its editor split's actual width.

## Numbers

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

Prefix buffer names with either the `ordinal` or `buffer id` using the `numbers` option,
specified as `buffer_id` | `ordinal` or a function.

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

See `:help bufferline-numbers`.

## Unique names

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

## Close icons

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

## Re-ordering

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

This order can be persisted between sessions (enabled by default).

## Picking

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

See `:help bufferline-pick`.

## Pinning

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

## Custom areas

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

See `:help bufferline-custom-areas`. Custom areas are single-row only and are not
supported with multiline.
