# Device catalog evidence

Retrieved 2026-10-20. A profile is not certification. Stages the simulator may assign here are PROFILED only.

Rejected figures from the research report were not stored: Amazfit case millimetres and PPI from an ambiguous product page, the Zepp watch-face preview size as a logical viewport, Apple 396×484, Apple crown-press reservation, Garmin 46×46×14.5, 240×240, 30.4 mm, and button names that were not in the retrieved text.

## Amazfit GTS 4

`profileId`: `amazfit-gts4`

| Fact | Status | Value |
| --- | --- | --- |
| Raster | known | 390 × 450 |
| Radius column | known | 86 |
| Display shape | derived | roundedRectangle from Square plus radius 86 |
| Design space | known | 390 × 450 Zepp square-screen benchmark |
| Native logical viewport | unknown | preview image size is not stored |
| Physical keys | known | 1 |
| Crown, touch, gestures, haptics, bezel | unknown | |
| Case millimetres | unknown | |
| Safe area, shell aperture | unknown | |

Sources:

- https://docs.zepp.com/docs/reference/related-resources/device-list/
- https://docs.zepp.com/docs/guides/framework/device/screen-adaption/

The US Amazfit product page mixed products. Case size, button count 2, 1.75 inch, and 341 PPI from that page were not used.

## Huawei Watch GT 4 46 mm

`profileId`: `huawei-watch-gt4-46`

| Fact | Status | Value |
| --- | --- | --- |
| Case | known | 46 × 46 × 10.9 mm |
| Case shape | derived | round, because both axes are 46 mm |
| Raster | known | 466 × 466 |
| Diagonal | known | 1.43 inch |
| PPI | known | 326 |
| Display shape | derived | round from the square raster |
| Native logical viewport and design space | unknown | raster is a fallback coordinate space, not a design space |
| Touch | supported | simulator may forward touch |
| Rotating crown, rotation, press, side button | supported | simulator does not yet dispatch those channels |
| Side button count | known | 1, separate from the crown |
| Rotating bezel, haptics | unknown | |
| Safe area, shell aperture | unknown | |

The 41 mm model is a different variant and is not part of this profile. Specs are described by Huawei as theoretical.

Sources:

- https://consumer.huawei.com/uk/wearables/watch-gt4/specs/
- https://consumer.huawei.com/en/support/content/en-us15818704/

## Apple Watch Series 9 45 mm

`profileId`: `apple-watch-series9-45`

| Fact | Status | Value |
| --- | --- | --- |
| Case | known | width 38 mm, height 45 mm, depth 10.7 mm |
| Case and display shape | derived | roundedRectangle |
| PPI | known | 326 |
| Digital Crown, side button, double tap, crown haptics | supported | crown and side button are not simulated channels yet |
| Touch | supported | with the uncertainty that the excerpt did not use the word touchscreen |
| Raster, logical viewport, design space, diagonal, corner radius | unknown | |
| Crown rotation and crown press | unknown | system-reserved was not confirmed |
| Rotating bezel | unknown | |
| Safe area, shell aperture | unknown | |

Source: https://support.apple.com/111833

Fetched Human Interface Guidelines pages did not return a usable layout table, so they are not cited as evidence for a raster.

## Garmin Approach S60

`profileId`: `garmin-approach-s60`

Identity is known from the owner manual: Garmin Approach S60. Platform family, case size, display shape, raster, touch, crown, and buttons are unknown. The Connect IQ device-reference URL returned a title only in this session.

Sources:

- https://www8.garmin.com/manuals/webhelp/approachs60/EN-US/GUID-E0C7F5F4-D845-44EC-A4E2-3F5E6A15C5D2.html
- https://developer.garmin.com/connect-iq/device-reference/approachs60/

The profile still loads. Unknown fields stay unknown.
