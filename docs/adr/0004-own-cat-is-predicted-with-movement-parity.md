# A client predicts its own Cat's movement; movement is the only rule kept at parity

Online, a client moves its own Cat at once instead of waiting for the server. Client and server advance in the same fixed steps, 60 a second. On every step the client sends one input carrying a sequence number and applies it locally with `movement.gd`. The server queues the inputs of each User, consumes one per Tick and reports the last sequence number it applied. The client then places its Cat where the server says and applies again the inputs not yet confirmed.

This needs both sides to move a Cat in exactly the same way. So movement is the exception to the frozen GDScript rules of [ADR 0003](0003-online-rules-run-on-the-server.md): `movement.gd` and its TypeScript twin must agree, and one file of cases (position, direction, Board, expected result) is run by the tests of both.

## Considered Options

- **No prediction, every Cat interpolated** — rejected: the Cat answers a key one round trip and one Tick late.
- **Prediction in the page, with the server's own TypeScript** — rejected: parity would be free, but the predicted position would need a second bridge between JavaScript and GDScript, called on every frame, beside Porter's Binding.
- **Prediction without exact parity, corrections smoothed** — rejected: every difference between the two implementations shows as a tug on the Cat, and nothing warns when it appears.
- **Only direction changes sent, not one input per step** — rejected: the server would apply a turn on a different step than the client predicted, so every turn would be corrected.
- **30 steps a second** — rejected: 60 is the step the local rules already use, so the port keeps its delta.

## Consequences

Only the movement of a client's own Cat is predicted. Other Cats, Bombs, Explosions, Powerups and deaths appear when the server says. A Cat can still die to an Explosion it had already left on its own screen.

The sequence numbers are part of BomberCat's own Game messages; Porter is not changed for them.

Where everything is on each Tick travels as a Game message with no Applier, so it reaches the scene that draws without going through the client's state. Porter's Binding for Godot serializes the whole Game only when that state changes, which a Tick alone does not do. Measured before anything was built on it, with a snapshot of 4 Cats and 8 Bombs at 60 Ticks a second in a web export: every message arrived, writing and parsing one again in GDScript took about 0.1 ms, and the frame rate stayed at 60.
