# Story pictures: right before the person sees them

A lesson product with `look.lesson.pictures` draws one picture per paragraph with a small local model
(FLUX klein, about 2–4 minutes a picture). It counts badly from words and draws what the sketch shows,
so most faults are in the text or the sketch, not the seed. The Story pictures rules in
`get_product_context` say how to write them. This is the loop that gets them right before a card exists.

## Before the first part
- **Settle every recurring object once.** Before writing any caption, list every object or place that appears in more than one picture of the tale (a pen, an oven, a house). Give each one its looks once in `story.json`'s `pictures.props`, then name it `{key}` in every caption and sketch label, like a character.
  An oven, a pen and a bread house retyped in each caption were drawn differently in every picture, and in every part.
- **Give the lead characters a sheet.** For the one or two characters who come back in most pictures (the heroine, the wolf), set `story.json`'s `pictures.sheets` (`{ "girl": "person", "wolf": "animal" }`). Studio draws each once for the whole tale (front, side and back on plain paper) and hands its head to every picture that names it, so the face and fur stop drifting between pictures. Only the head is taken: the caption still decides the clothes and pose. Never a sheet for a group or an extra; each sheeted picture takes about 5 minutes more.
- **Draw and check the whole tale before the person sees any part.** Each object is then settled across parts before anyone reviews one.

## The loop, per part
1. **Write the version** with `write_story`. Fix every warning about pictures. Each one is a fault seen in an earlier tale.
2. **Read the sketches** it returns (`sketches`). The picture keeps the sketch's layout, so check it first:
   - one figure per counted thing;
   - every character where the text puts it;
   - nothing important in the lower third.
3. **Draw**: `draw_pictures` for the part, then `get_job` with `waitSeconds: 300`, again until it ends.
   The render reuses these pictures, so drawing now costs nothing extra.
   With sheets, the first draw returns only the sheets (`sheet:<key>`, with `head`, the head cut from it). Read the sheet and its head:
   - one character, three times, the front view on the left, nothing else on the paper;
   - it matches its looks;
   - the head file holds the whole head and face.
   Send `review_pictures` for each sheet (a wrong one: `redraw: ["sheet:<key>"]` or fix its looks), then `draw_pictures` again for the pictures.
4. **Look**: read each picture beside its sketch. Check:
   - every counted group has the sketch's number;
   - each character is drawn once;
   - every animal is a real animal: one head, two ears, four legs, no human hands;
   - a figure in a window shows only its head (a person, head and shoulders);
   - no lettering or signature;
   - each character and object matches the earlier pictures in its `compare` list (`draw_pictures` returns them for each picture, the previous part's too). Read them side by side, not each picture on its own;
   - every face has its eyes, nose and mouth, and every person has their hands;
   - each character carries what the text gives them, once (one crutch, not two);
   - a character drawn from a sheet has the sheet's face but the caption's clothes and shoes (the girl once lost her wooden shoes);
   - no part of an object is drawn twice (doubled bars beside an open gate);
   - the main subject is above the lower third;
   - the picture tells this paragraph's event, with only the characters it needs. Don't add the heroine by habit: Aschenputtel standing beside the king as he proclaimed the feast made no sense;
   - it fits the story at this moment: who has fled, who is hidden, who can see whom. A seeker never faces the one hiding from him (turn his back, `facing` away in the sketch), and a hiding place she has fled is drawn empty. Read the paragraph before and after, not just the caption.
   These last two are what the person caught after my own look passed every Aschenputtel picture: a well-drawn picture can still be wrong for the story.
5. **Fix or redraw**:
   - A wrong count, a missing or extra figure, or a figure in the wrong place is the text's or the sketch's fault.
     Fix it with `write_story`, which makes a new picture to draw.
   - A stray limb or a smudged face on a right layout is the seed's fault. Use `draw_pictures` with `redraw: [paragraph]`.
   - A malformed hand is the seed's fault the first time (redraw). A hand that grips a small object (a shoe, a ring) was malformed again: write the object resting on the open, flat palm, in the caption and the sketch label.
6. **Review**: `review_pictures`, one verdict per picture.
   - After three tries at one picture, pass it with `ok: true` and a note saying what is still off. The person sees the note beside it.
   - `add_lesson_videos` and `request_recording` are refused until every picture of the part has an ok.

## Reading pictures
- Picture files are named by what draws them, so a redrawn picture is a new file.
- The copies under a video's `lesson/pictures/NN.png` keep their name across renders. Reading one again can show the old image.
  Read the files `draw_pictures` returns, or copy a `lesson/pictures` file under a new name first.

## After fixing pictures of a rendered tale
Each video (the full story and each part) copies its pictures when it renders, so a fix shows up only in the videos rendered again. Render every video that holds a changed paragraph (`request_recording` with `reviseNote`), then compare each `lesson/pictures` file's md5 against the new picture. Until then the person still sees the old picture in every video (they asked why the girl was still in part 1).

## Lessons from earlier tales
The full record is in Studio's `docs/lessons.md` § Story pictures. In short:
- Looks never carry a pose ("standing"): the model draws both poses.
- A picture never counts body parts ("four hooves", "two eyes"): the model adds them to the ones it draws.
- An animal never does anything with hands.
- A person and an animal are sketched apart, or they trade features.
- A barred opening (a pen, a cage) is a `cage` shape, never a `window`. A window's centre bar left a wide gap round Hänsel's face, and its panes stayed closed bars beside the open gate.
- An oven is an `oven` shape, with its own door (`state: "open"` or `"shut"`) and a `fire` in its mouth. Figures are drawn farther (higher feet) first, so a door sketched as its own figure was drawn behind the oven's wall. Use `z` for anything else that must be in front.
- A one-line caption draws a generic picture. Write the full scene every time.
- A passing mark (ash, soot, a smudge, tears) goes in the captions where it belongs, never in the looks: Aschenputtel's ash smudge was drawn on her wedding face and spread to her stepsisters.
- A place seen outside and inside is two props: one `{cottage}` describing both drew its thatch indoors and its spinning wheel outdoors. Name each object once per picture: a wheel in the room's looks and again in the caption was drawn twice.
- Never call a man stout or stocky in his looks: the model draws a dwarf.
- Never show a looks item leaving a character (a hat flying off): the looks keep it on, and the model draws a second one.
- Horse, bed, table, tower and throne are sketch shapes, and kneeling is a person's `pose`. Sketch them rather than leaving them to words.
- A name Whisper mishears in every line goes in story.json's `heardAs`, so it is not re-voiced four times per line.
- An animal with hanging ears (a hound, a lop rabbit) is sketched with `"ears": "down"` (or story.json `pictures.ears { "dog": "down" }`): the default sketch ears stand up and were painted on the Bremen hound as two more ears, like horns.
- A tiny character (Thumbling) needs a sketch in every picture he's in, at the minimum size (0.03), placed against something adult-sized: a shoulder, a hat brim, a boot. Two Daumesdick paragraphs with `sketch: null` drew him child-sized. Behind a barred window he stayed half an adult head even at 0.03 after three tries: a window frames a child.
- A character "cupping his hands at" another's ear drew a third hand on the listener. Give the listener's arms in the caption ("both arms down at his sides").
- A looks item held in the hand (a hat) is drawn twice, once worn and once held. The same rule as a hat flying off.
- Sketch sizes set heights: strangers sketched at 0.5 and 0.4 stayed a man and a child whatever the caption said. Make figures meant to be the same height within ~0.03 of each other.
- The sketch rejects `pose: "crouch"` on a person (animals only), `state` on a door (cage and oven only), sizes below 0.03 and y above 1.
- A story whose cart has no sketch shape: use the `horse` shape and write the cart "directly behind the horse, in line with it, on two straight shafts". The `animal` shape plus {cart} drew the cart sideways beside the horse.
