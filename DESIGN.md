# Chirpkey design

Built on Graphite (neutrals, Geist, cobalt accent, 4 px grid, hairlines).

- **Layout:** a tinted window with a 216 pt sidebar; content is one inset rounded sheet. Places you use sit at the top of the sidebar, Settings and Profile at the bottom, which open one modal with tabs over a dimmed window. Home has a 232 pt right column for progress and next steps.
- **Theme:** light by default. Settings and the top-right button change it.
- **Signature:** the voice field, cobalt to sky to mint with a white ribbon that follows the microphone. It appears only where the app is about your voice (Home, Your voice). The pill, logo, icon and avatar reuse its colors. Nothing else gets a gradient.
- **Color:** cobalt is selection, data and the main action. Red is for deleting and errors.
- **Type:** Geist. Display 32, page 24, title 20, body, small. Tight tracking above 20.
- **Motion:** the sidebar selection slides (spring 0.28, no bounce); new dictations slide in from the top; numbers roll; buttons press to 0.97. Keyboard shortcuts switch instantly. The field stops when the window is inactive and with Reduce Motion.
- **Progress:** ranks count spoken words; the week row and next steps show only what really happened. A new rank gets one quiet toast.
