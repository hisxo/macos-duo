# Video study and macOS adaptation

## References actually inspected

1. [Hands-on video](https://www.youtube.com/shorts/QcbWCxE2a1c). Inspected time-stamped frames, including 24 frames at 0.25-second intervals from 11s and 24 at 0.2-second intervals from 18s.
2. [Marques Brownlee hands-on](https://www.youtube.com/watch?v=uJdjKOBikTE). Inspected the overall sequence plus close/open transitions at 0.08- and 0.1-second intervals.
3. [Apple's iPhone Duo product page](https://www.apple.com/iphone-duo/). Inspected 20 frames from the 3.033-second hero animation downloaded from the page's media path.

Reference videos and extracted contact sheets are not distributed with this repository or app. They are research material only.

## Observations from the supplied video

| Video interval | Visible behavior | Implementation consequence |
| --- | --- | --- |
| 12.50–13.00s | Outer content loses definition as the cover rotates; the internal stationary display remains readable. | Separate moving-surface optics from the unaffected desktop outside the built-in screen. |
| 13.25–14.25s | The moving inner half shows broad cloudy color, increasing darkness at its distant edge, and clearer content near the hinge. | Use a spatial blur field driven by distance from the hinge. Do not introduce lateral black bands on the Mac display. |
| About 14.50s | Opening resolves the moving half to a sharp full layout. | At the open endpoint the original image is unchanged and the overlay disappears. |
| 18.00–19.40s | Closing passes through a narrow, dark edge-on phase; a blurred outer-screen image then becomes visible. | The Mac reproduces the moving inner-display phase. It has no outer display to reveal after closing. |
| 20.60–22.60s | The presenter repeatedly reverses the motion; the cloudy state follows the changing pose. | Actual lid angle is the source of progress. No fixed-duration automatic close animation. |

The earlier hands-on clip corroborates this: at 6.76s the inner layout is crisp; by 6.84s the moving half is visibly frosted. At 10.90–11.10s it resolves again while opening. Apple's product animation likewise keeps the right side readable while the left photo widget resolves near the end.

These are visual observations, not recovered Apple shader parameters. The videos do not provide synchronized hinge telemetry, camera calibration, or uncompressed screen pixels, so exact blur radii and optical constants cannot be measured reliably from them.

## Rendering model

For the Mac, rotate the concept to the bottom hinge. Let `h` be normalized distance above that hinge, `p` closing progress, and `theta = p × (startAngle − 5°)`. Use the actual configured angular span, rather than an unrelated decorative rotation.

The rotating surface point is `(x, h cos(theta), h sin(theta))`. A virtual eye sits at `(0.5, 0.5, D)` with `D = 2.4` screen heights. Intersect its ray through that point with the original screen plane. The intersection factor is `t = D / (D − h sin(theta))`. This determines source-image sampling coordinates; at the hinge, `t = 1`, so the edge remains anchored.

Blur increases with `h sin(theta) × t`, scaled by the Frost control and source resolution. The renderer prepares Gaussian-filtered mip levels once when the desktop is captured; the shader interpolates blur levels per pixel. Both Gaussian filtering and projected sampling extend the source's edge colors beyond the captured bounds. Returning black there was an error in the first version: it produced lateral wedges and blur halos absent from the requested effect. A low-amplitude cool haze and increasing extinction reproduce the cloudy glass appearance. Full closing ends at black. Opening evaluates the identical function in reverse, so stopping or reversing midway does not restart an animation.

The hardware is polled at 60 Hz off the main thread, with modest smoothing to suppress sensor steps. GPU rendering is requested only while an overlay is active or preview changes. A static desktop snapshot avoids capturing the overlay recursively. Capture completion is generation-checked so an old screenshot cannot bring back a dismissed overlay.

## Deliberate Mac-specific differences

The iPhone transfers between distinct inner and outer interfaces. A MacBook provides one moving display, so the adaptation preserves its desktop image and changes its optical appearance as the physical lid moves. It cannot create a real second display behind the lid.

The closing threshold defaults to 75°. A second adjustable range starts above 120° and reaches its configured maximum at 165°, with 65% intensity by default. The backward range uses a negative rotation span and the absolute distance from the reference plane for blur. The neutral range remains clear. These are software parameters, not instructions to exceed a laptop's physical hinge range. Eye distance is an approximation; the app does not track the viewer's head. A 5.5-second preview cycle is provided for inspection only.

Secure lock screens and sleep are owned by macOS. The app clears the overlay on lock/sleep and supports opening while unlocked. Therefore this is an independently implemented visual adaptation, not a claim of an exact copy of Apple's private implementation.

## Verification scope

GPU checks verify the open/closed endpoints, reversibility at matching angles, visible intermediate changes, and successful rendering. Native integration checks verify the full-screen panel, Metal drawables, click-through, Escape dismissal, stale asynchronous-capture rejection, and full demo cleanup. The hardware probe reports sensor availability on the machine running the tests.

Manual validation: grant Screen Recording, then close/reopen the laptop while viewing it head-on. Check capture handoff and perceived geometry from a normal seating position. Automated tests cannot physically move the lid or establish optical fidelity for every viewing position.
