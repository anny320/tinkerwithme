-- Young Engineers v2: 18 hands-on lessons (3 builds per age stage), with illustrations
-- in assets/courses/young-engineers/. Run in Supabase -> SQL Editor, in 3 parts, in order.
-- Each part is safe to run more than once. Keeps the course's link, price, cover and
-- publish setting, and replaces all its lessons (lessons 1 and 4 are free previews).

-- PART 1 of 3: course details + lessons 1-6
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'young-engineers';
  if cid is null then
    insert into public.lms_courses (slug, title, price_kes, is_published, position) values ('young-engineers', 'Young Engineers', 5000, false, 5) returning id into cid;
  end if;
  update public.lms_courses set summary = $tw$Think, build, test and improve like a real engineer: 18 hands-on lessons, from paper bridges and balloon cars to Arduino traffic lights, smart streetlights and a real-world capstone.$tw$, description = $tw$**Robotics is our playground. Engineering is the superpower.**

Young Engineers teaches children to think and work like engineers: ask good questions, build things, test them, measure what happens, and make them better. Every stage has **three hands-on builds** with a materials list, step-by-step instructions, a results table and a challenge to improve it.

**What your child will build**

- **Ages 5–7:** a paper bridge, a balloon-powered car and a light-up card
- **Ages 8–10:** an algorithm maze, a catapult experiment and a smart traffic light
- **Ages 11–13:** a hydraulic robot arm, a line-follower sensor and a waste-sorting machine
- **Ages 14–16:** a paper-helicopter experiment, an AI that sees, and a smart streetlight
- **Ages 16–18:** a real-world capstone project, from user interview to pitch

**How it works**

- 18 lessons, each with a quiz. Start with your own age stage, or do them all.
- Most builds use things you already have at home: card, tape, straws, balloons, syringes. The electronics builds use the [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html), or a free online simulator instead.
- Younger children build with a grown-up; older learners can work on their own.
- Keep an **Engineer's Notebook** throughout, and earn a certificate at the end.

## Questions parents ask

**Do we need the Maker Kit?**
No. Most builds use things you already have at home. The four electronics builds (traffic light, line sensor, smart streetlight and the automatic sorting gate) can be done in the free [Tinkercad Circuits](https://www.tinkercad.com/circuits) simulator instead. The kit lets your child build them for real, and it's reused in every Tinkerwith Arduino course.

**What's in the Tinkerwith Maker Kit?**

![The Tinkerwith Maker Kit contents](https://tinkerwith.me/assets/courses/young-engineers/maker-kit.svg)

An Arduino Uno with USB cable, a breadboard and 40 jumper wires, LEDs in 5 colours with resistors, push buttons, a dial (potentiometer), a buzzer, a light sensor, a sound sensor, an ultrasonic distance sensor, an IR line sensor, a temperature and humidity sensor, a motion sensor, a servo motor, a relay module, an LCD screen, a battery holder and a storage box. **KES 8,500 one-time** (US$99 outside Kenya), plus delivery. [Order it from Anne on WhatsApp](https://wa.me/254117784724?text=Hi%20Anne%2C%20I%27d%20like%20to%20order%20the%20Tinkerwith%20Maker%20Kit.).

**What ages is it for?**
Ages 5 to 18. Each age stage has its own three builds. Younger children build with a grown-up; older learners can work on their own.

**Can we try it first?**
Yes. Lesson 1 (the Tinker Loop) and lesson 4 (the paper bridge) are free to open.

**How long do we have access?**
12 months from the day your payment is approved, on any phone, tablet or computer.$tw$,
    age_range = '5–18', updated_at = now(),
    cover_url = case when cover_url = '' then 'https://tinkerwith.me/assets/courses/young-engineers/cover.svg' else cover_url end
  where id = cid;
  delete from public.lms_lessons where course_id = cid;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 1, $tw$Start here$tw$, $tw$Your mission: the Tinker Loop$tw$, $tw$## 🎯 Your mission

Engineering isn't about getting everything right the first time. It's about asking great questions, making things, testing them, learning from failure and making them better.

### The Tinker Loop

![The Tinker Loop: think, design, build, test, measure, diagnose, improve, explain](https://tinkerwith.me/assets/courses/young-engineers/tinker-loop.svg)

This is how engineers work, every time:

1. **Think**: what is the problem?
2. **Design**: plan a solution. Draw it!
3. **Build**: make it.
4. **Test**: try it out.
5. **Measure**: collect evidence instead of guessing.
6. **Diagnose**: work out why it did (or didn't) work.
7. **Improve**: change **one thing** and try again.
8. **Explain**: share what you made so others can understand it.

> When something fails, that isn't the end. **Failure is data.** Ask: *What happened? What changed? What does the evidence tell us?*

### ✏️ Activity: start your Engineer's Notebook

Every engineer keeps a notebook. Get an exercise book and:

1. Write **"Engineer's Notebook"** and your name on the cover.
2. On page 1, draw the Tinker Loop in your own way.
3. Write one thing you'd love to build one day.

You'll use this notebook in every lesson.

### 🧰 Your home engineering box

Start collecting these, they're used again and again: cardboard and cereal boxes, paper, tape, scissors, straws, lollipop sticks, rubber bands, bottle tops, balloons, a ruler or tape measure, and a stopwatch (a phone is fine).

> **Grown-up tip:** let them make mistakes. Ask "what happened?" before you help.$tw$, $tw$[{"q": "Your robot fails its test. What should an engineer do first?", "options": ["Throw it away", "Investigate why it failed", "Blame the robot"], "answer": 1}, {"q": "Which step comes straight after Build in the Tinker Loop?", "options": ["Explain", "Think", "Test"], "answer": 2}, {"q": "What does \"failure is data\" mean?", "options": ["A failed test tells you something useful", "Failing means you should stop", "Computers store failures"], "answer": 0}]$tw$::jsonb, true);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 2, $tw$Start here$tw$, $tw$The Young Engineer Journey$tw$, $tw$## 🗺️ The Young Engineer Journey

![The five stages of the Young Engineer Journey, from Explorer to Innovator](https://tinkerwith.me/assets/courses/young-engineers/journey.svg)

Every engineer grows through stages. Find yours!

| Stage | Age | Engineer identity | Big question |
|---|---|---|---|
| 🌱 Engineering Explorer | 5–7 | I can make things. | What can I build? |
| 🔧 Junior Maker | 8–10 | I can solve problems. | How can I make it work? |
| 🤖 Junior Engineer | 11–13 | I can design systems. | How can I design it better? |
| ⚙️ Engineer | 14–16 | I can engineer solutions. | Why does it work? |
| 🚀 Engineering Innovator | 16–18 | I can create solutions. | How can I solve a real problem? |

### How to use this course

- **Start with your own stage.** Each stage has three builds.
- **Younger?** Do the builds with a grown-up.
- **Older?** Do your stage, then try the earlier builds as a speed challenge: can you improve them using what you know now?

### ✏️ Activity

In your notebook, write your stage and its big question. Then answer it: what would *you* like to build?$tw$, $tw$[{"q": "Which stage asks the big question \"How can I make it work?\"", "options": ["Engineering Explorer", "Junior Maker", "Engineering Innovator"], "answer": 1}, {"q": "What is the engineer identity of a Junior Engineer (11–13)?", "options": ["I can design systems.", "I can make things.", "I can create solutions."], "answer": 0}, {"q": "Which stage is about solving real problems in the world?", "options": ["Junior Maker", "Engineer", "Engineering Innovator"], "answer": 2}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 3, $tw$Start here$tw$, $tw$The 8 engineering superpowers$tw$, $tw$## 🧩 The 8 engineering superpowers

![The 8 engineering superpowers](https://tinkerwith.me/assets/courses/young-engineers/superpowers.svg)

Engineers combine many skills. You'll build up all 8 in this course:

1. **Design**: turn a problem into a plan.
2. **Maths**: measure, calculate, compare and predict.
3. **Science**: understand forces, energy, motion and electricity.
4. **Electronics**: make sensors, motors and circuits work together.
5. **Code + AI**: give machines instructions and intelligence.
6. **CAD + Making**: design before you build; make your ideas real.
7. **Test + Data**: measure performance instead of guessing.
8. **Communicate**: explain your design so others can build on it.

### 🔍 Activity: superpower spotting

Pick something at home that was engineered: a bicycle, a water tank, a phone charger, a matatu door.

1. Draw it in your notebook.
2. Label which superpowers its engineers needed. (A water tank needs **Maths** for its size, **Science** for water pressure, and **Making** to build it.)
3. What would you improve about it?

### 🌍 Engineers in real life

Kenya's engineers use all 8 superpowers: designing the **Nairobi Expressway**, building **solar mini-grids** for villages, and making **M-Pesa** work on millions of phones.$tw$, $tw$[{"q": "Which superpower is about measuring performance instead of guessing?", "options": ["Design", "Test + Data", "Communicate"], "answer": 1}, {"q": "\"Give machines instructions and intelligence\" describes which superpower?", "options": ["Code + AI", "Science", "Maths"], "answer": 0}, {"q": "Why does an engineer need to Communicate?", "options": ["To make the robot faster", "So others can understand and build on the design", "Because it's the last step of school"], "answer": 1}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 4, $tw$Ages 5–7: Engineering Explorers$tw$, $tw$Build: the paper bridge$tw$, $tw$## 🌱 Engineering Explorers (ages 5–7)

Explorers learn by playing, building and trying again. Today: **shapes make things strong**.

### 🚧 Challenge: The Bridge Builder

![A flat paper bridge sags, a folded one holds 10 blocks](https://tinkerwith.me/assets/courses/young-engineers/bridge-challenge.svg)

⏱️ 30 minutes · 👫 With a grown-up

**You need:** 2 sheets of paper, 2 stacks of books (the same height), small blocks or coins, tape.

### Steps

1. Make two towers of books, a ruler's length apart.
2. Lay **one flat sheet** across the gap. Put blocks on it one at a time. How many before it falls? Write the number down.
3. Now **fold a new sheet like a fan** (zig-zag folds, about 2 cm wide). Lay it across the gap.
4. Add blocks one at a time again. How many now?

### 📊 Results

| Bridge | Blocks it held |
|---|---|
| Flat paper | |
| Fan-folded paper | |
| My own idea | |

### 🔄 Improve it

Change **one thing** and test again: fold it into a tube? Add a second layer? Tape the ends down? Which shape held the most?

> **Why does it work?** Folds make the paper stiff, like the ridges on a mabati roof or the pattern on a cardboard box.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

⭐ **Engineer move unlocked: test and improve!**$tw$, $tw$[{"q": "Your bridge holds 6 blocks. What should you do next?", "options": ["Give up", "Change one thing and test again", "Change everything at once"], "answer": 1}, {"q": "Why change only one thing at a time?", "options": ["So you know what made the difference", "Because it's faster", "So the bridge looks nicer"], "answer": 0}, {"q": "Why did folding the paper make it stronger?", "options": ["The folds made it stiffer", "Folding made it heavier", "It's magic"], "answer": 0}]$tw$::jsonb, true);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 5, $tw$Ages 5–7: Engineering Explorers$tw$, $tw$Build: the balloon-powered car$tw$, $tw$## 🎈 Build: the balloon-powered car

Today you'll learn about **push** and **pull**: a force makes things move.

![A balloon-powered car made from a box, straws and bottle-top wheels](https://tinkerwith.me/assets/courses/young-engineers/balloon-car.svg)

⏱️ 45 minutes · 👫 With a grown-up (sharp skewers!)

**You need:** a small juice box or piece of card, 2 straws, 2 wooden skewers, 4 bottle tops, a balloon, 1 more straw, tape.

### Steps

1. **Axles:** tape 2 straws across the bottom of the box, one at each end.
2. Push a skewer through each straw. A grown-up makes a hole in the middle of each bottle top and pushes them onto the skewer ends. These are your **wheels**.
3. Check the wheels spin freely. If they rub, move the straws.
4. **Engine:** tape the balloon's neck around one end of the spare straw, sealing it tight.
5. Tape the straw on top of the car with the balloon at the front and the straw sticking out the back.
6. Blow up the balloon through the straw, pinch it, put the car down and **let go!**

### 📊 Results

Measure how far it goes with a tape measure.

| Try | Balloon size | Distance |
|---|---|---|
| 1 | Small | |
| 2 | Big | |
| 3 | My change | |

### 🔄 Improve it

Try **one** change: bigger wheels, a lighter body, a longer straw. Which went furthest?

> **Why does it work?** Air rushes **backwards** out of the straw, and that pushes the car **forwards**. Rockets work the same way!

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

📸 **Share your build:** send a photo or a few words on our [Share your story](https://tinkerwith.me/stories.html) page.$tw$, $tw$[{"q": "Air rushes out of the back of the car. Which way does the car move?", "options": ["Backwards", "Forwards", "Up"], "answer": 1}, {"q": "Your car goes in a circle. What might be wrong?", "options": ["The wheels or axles aren't straight", "The balloon is red", "It needs more tape on top"], "answer": 0}, {"q": "How do you know which change made your car faster?", "options": ["Measure the distance each time", "Guess", "Ask a friend which looks fastest"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 6, $tw$Ages 5–7: Engineering Explorers$tw$, $tw$Build: the light-up card$tw$, $tw$## 💡 Build: the light-up card

Today you'll make your first **circuit**: a path electricity flows around.

![A light-up card with an LED, a coin battery and a paper-clip switch](https://tinkerwith.me/assets/courses/young-engineers/light-card.svg)

⏱️ 30 minutes · 👫 With a grown-up

**You need:** card, a coin battery (CR2032), one LED, tape, a paper clip. *(Or copper tape, if you have some.)*

> ⚠️ **Safety:** coin batteries are dangerous if swallowed. A grown-up keeps them, and puts them away after.

### Steps

1. Draw a picture on your card: a house, a robot, a star. Choose where the light will go.
2. Push the LED's legs through the card from the front.
3. Look at the LED: one leg is **longer**. That's the **+** leg.
4. Bend the long leg so it touches the **+** side of the battery (the side with writing). Bend the short leg to touch the **−** side. Tape it. Does it light?
5. **Make a switch:** cut the short leg's path and use a paper clip to join it. Press the clip down: light on! Lift it: light off.

### 📊 Test it

| Test | Does it light? |
|---|---|
| Legs the right way round | |
| Legs swapped round | |
| Switch pressed | |
| Switch lifted | |

### 🔄 Improve it

Can you add a second LED? Does it work if both long legs go to **+**?

> **Why does it work?** Electricity needs a **complete loop** from + back to −. The switch opens and closes the loop.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

⭐ **Engineer move unlocked: circuits!**$tw$, $tw$[{"q": "What does electricity need to light the LED?", "options": ["A complete loop from + to −", "Just one wire", "A bigger card"], "answer": 0}, {"q": "Which leg of the LED goes to the + side?", "options": ["The short leg", "The long leg", "It doesn't matter"], "answer": 1}, {"q": "What does a switch do?", "options": ["Opens and closes the loop", "Makes the battery bigger", "Changes the LED colour"], "answer": 0}]$tw$::jsonb, false);
end $$;

-- PART 2 of 3: lessons 7-12
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'young-engineers';
  if cid is null then raise exception 'Run part 1 first.'; end if;
  delete from public.lms_lessons where course_id = cid and position between 7 and 12;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 7, $tw$Ages 8–10: Junior Makers$tw$, $tw$Activity: be the algorithm$tw$, $tw$## 🔧 Junior Makers (ages 8–10)

Makers solve problems with rules, measurement and simple experiments. First: **algorithms**, the step-by-step instructions every robot follows.

![A grid maze with a robot, a star and a list of program commands](https://tinkerwith.me/assets/courses/young-engineers/algorithm-maze.svg)

⏱️ 40 minutes · 👫 Best with a partner

### Part 1: the human robot (unplugged)

1. Draw a 6 × 6 grid on the floor with chalk or tape, or on paper. Add some "walls" and a ⭐.
2. One person is the **robot**. The robot can only understand: **Forward 1, Turn left, Turn right**.
3. The **programmer** writes the full program on paper first, *without* speaking to the robot.
4. The robot follows it exactly. Did it reach the ⭐? If not, find the **bug** and fix it.

### Part 2: make it shorter

Engineers love short programs. Can you use **Repeat**? (For example: "Repeat 3: Forward 1".) Count the steps in your first program and your shortest one.

### Part 3: on a computer (optional)

On [Scratch](https://scratch.mit.edu/projects/editor/), make a sprite walk through a maze you draw. Use **if touching colour… then** to bounce off walls.

### 📊 Results

| Program | Number of steps | Reached the ⭐? |
|---|---|---|
| First try | | |
| With Repeat | | |

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

⭐ **Engineer move unlocked: algorithms!**$tw$, $tw$[{"q": "What is an algorithm?", "options": ["A step-by-step set of instructions", "A type of robot", "A computer screen"], "answer": 0}, {"q": "The robot walked into a wall. What's that called?", "options": ["A bug", "A feature", "A battery"], "answer": 0}, {"q": "Why use Repeat?", "options": ["To make the program shorter and clearer", "To make the robot slower", "Robots like it"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 8, $tw$Ages 8–10: Junior Makers$tw$, $tw$Build: the catapult experiment$tw$, $tw$## 🎯 Build: the catapult experiment

Real engineers **measure instead of guess**. Today you'll build a catapult and use data to make it better.

![A lollipop-stick catapult with a results table](https://tinkerwith.me/assets/courses/young-engineers/catapult.svg)

⏱️ 45 minutes

**You need:** 7 lollipop sticks, 4 rubber bands, a bottle top, glue or tape, paper balls (scrunched paper), a tape measure.

### Steps

1. Stack **5 sticks** and wrap a rubber band tightly around each end.
2. Put the other **2 sticks** together and wrap a band around **one end only**.
3. Push the stack of 5 between the 2 sticks, close to the banded end. It makes a cross shape.
4. Wrap a band in a criss-cross where the sticks meet to hold it.
5. Glue the bottle top to the top stick's free end. That's your **launcher**.
6. Put a paper ball in, press down and let go!

### 📊 The experiment

Change **one thing only**: the number of sticks in the stack (the **pivot height**). Fire 3 times for each and work out the average.

| Sticks in stack | Try 1 | Try 2 | Try 3 | Average |
|---|---|---|---|---|
| 3 | | | | |
| 5 | | | | |
| 7 | | | | |

**Average** = add the 3 distances, then divide by 3.

### 🔄 Improve it

Now aim for a cup 1 metre away. Use your data to pick the best setup *before* you fire. Did your prediction work?

> **Why 3 tries?** One try can be lucky. Averages give you **evidence**.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

⭐ **Engineer move unlocked: measure instead of guess!**$tw$, $tw$[{"q": "Why fire 3 times and take the average?", "options": ["One try might be lucky or unlucky", "It's more fun", "The catapult gets warmer"], "answer": 0}, {"q": "In a fair test, how many things do you change at once?", "options": ["One", "Two", "As many as possible"], "answer": 0}, {"q": "Your average is 120 cm. Using data to aim at a cup is called…", "options": ["Predicting", "Guessing", "Copying"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 9, $tw$Ages 8–10: Junior Makers$tw$, $tw$Build: the smart traffic light$tw$, $tw$## 🚦 Build: the smart traffic light

Now for real electronics! A **smart** traffic light changes when someone is waiting.

![A traffic light turns green when its sensor sees a waiting car](https://tinkerwith.me/assets/courses/young-engineers/smart-traffic.svg)

⏱️ 60 minutes · 🧰 [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html), or [Tinkercad Circuits](https://www.tinkercad.com/circuits) (free, in a browser, with a grown-up's account)

**You need:** Arduino Uno + USB cable, breadboard, red, yellow and green LEDs, 3 × 220 Ω resistors, 1 push button, jumper wires, a computer with the free [Arduino IDE](https://www.arduino.cc/en/software).

### Wiring

1. Put the 3 LEDs on the breadboard. Each LED's **long leg** connects to an Arduino pin through a 220 Ω resistor: **red → pin 10, yellow → pin 9, green → pin 8**.
2. Each LED's **short leg** goes to **GND**.
3. The button is our "sensor": one side to **pin 2**, the other side to **GND**.

### The code

~~~
const int RED = 10, YELLOW = 9, GREEN = 8, BUTTON = 2;

void setup() {
  pinMode(RED, OUTPUT); pinMode(YELLOW, OUTPUT); pinMode(GREEN, OUTPUT);
  pinMode(BUTTON, INPUT_PULLUP);   // pressed = LOW
  digitalWrite(GREEN, HIGH);       // cars go
}

void loop() {
  if (digitalRead(BUTTON) == LOW) {          // someone is waiting
    digitalWrite(GREEN, LOW);  digitalWrite(YELLOW, HIGH); delay(2000);
    digitalWrite(YELLOW, LOW); digitalWrite(RED, HIGH);    delay(5000);  // people cross
    digitalWrite(RED, LOW);    digitalWrite(GREEN, HIGH);
  }
}
~~~

Upload it, then press the button. Green → yellow → red → green!

### 📊 Test it

| Test | What happened? | As expected? |
|---|---|---|
| Press once | | |
| Press twice quickly | | |
| Hold the button down | | |

### 🔍 Diagnose

What if the sensor gives the **wrong reading**? Try pressing the button very lightly. Does the light ever change by mistake? How could you make it more reliable? *(Hint: check the button is still pressed after a short delay.)*

### 🔄 Improve it

- Change the timings: how long do people need to cross?
- Add the buzzer so it beeps while people can cross.

### 🌍 Engineers in real life

Nairobi's busiest junctions use sensors and timing plans just like this to keep traffic moving.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

⭐ **Engineer move unlocked: sensors!**$tw$, $tw$[{"q": "What does the button do in this build?", "options": ["Acts as a sensor that someone is waiting", "Powers the Arduino", "Makes the LEDs brighter"], "answer": 0}, {"q": "With INPUT_PULLUP, what does the pin read when the button is pressed?", "options": ["HIGH", "LOW", "Nothing"], "answer": 1}, {"q": "Which part protects each LED from too much current?", "options": ["The resistor", "The breadboard", "The USB cable"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 10, $tw$Ages 11–13: Junior Engineers$tw$, $tw$Build: the hydraulic robot arm$tw$, $tw$## 🤖 Junior Engineers (ages 11–13)

Junior Engineers design **systems** and make decisions with evidence. Your first system: a robot arm powered by water.

![A cardboard robot arm lifted by water-filled syringes](https://tinkerwith.me/assets/courses/young-engineers/hydraulic-arm.svg)

⏱️ 90 minutes · 👫 A grown-up helps with cutting

**You need:** stiff cardboard, 4 syringes (10 ml), 2 thin tubes (about 50 cm), split pins or skewers, water (add food colour to see it move), tape, glue.

### Steps

1. **Base:** glue a cardboard upright (about 15 cm) to a flat base.
2. **Arm:** cut 2 strips (20 cm and 15 cm). Join them to the upright and to each other with split pins so they can **pivot**.
3. **Gripper:** fold a small strip into a "V" at the end of the arm.
4. **Hydraulics:** fill one syringe with water, connect a tube, and connect an empty syringe on the other end (plunger pushed in). No air bubbles!
5. Tape the second syringe so that pushing it lifts the arm. Make a second pair for the elbow.
6. Push and pull the "controller" syringes to move the arm.

### 📊 Experiment

Can it lift a bottle top? A pencil? Measure the **heaviest** object it can lift and how **high**.

| Object | Lifted? | Height (cm) |
|---|---|---|
| Bottle top | | |
| Pencil | | |
| Eraser | | |

### 🔍 Diagnose

Try one pair with **air** instead of water. What's different? *(Air squashes; water doesn't. That's why real diggers use oil.)*

### 🌍 Engineers in real life

Excavators, aeroplane brakes and car lifts all use **hydraulics**: liquid in tubes moving heavy loads.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

📸 **Share your build:** send a photo or a few words on our [Share your story](https://tinkerwith.me/stories.html) page.$tw$, $tw$[{"q": "Why does water work better than air in the syringes?", "options": ["Water doesn't squash, so it pushes straight through", "Water is heavier", "Air is invisible"], "answer": 0}, {"q": "Which machines use hydraulics?", "options": ["Excavators and car lifts", "Torches", "Calculators"], "answer": 0}, {"q": "Where should the arm's joints be so they can move?", "options": ["At pivots held by split pins", "Glued solid", "Taped flat"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 11, $tw$Ages 11–13: Junior Engineers$tw$, $tw$Build: the line-follower sensor$tw$, $tw$## 〰️ Build: the line-follower sensor

Self-driving robots in warehouses follow lines on the floor. Today you'll learn the **logic** and build the **sensor**.

![A robot with two sensors on a black track, and its IF/THEN rules](https://tinkerwith.me/assets/courses/young-engineers/line-sensor.svg)

⏱️ 60 minutes · 🧰 [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html) for Part 2, or [Tinkercad Circuits](https://www.tinkercad.com/circuits) (free, in a browser, with a grown-up's account)

### Part 1: be the line follower (unplugged)

1. Make a track with black tape (or a thick marker) on white paper, with curves.
2. One person is the robot, with two fingers as **sensors** just either side of the line.
3. Follow the **rules** in the picture. Only move when a rule says so!
4. Where does the robot go wrong? Write a new rule to fix it.

### Part 2: build the sensor

**You need:** Arduino, IR sensor module, jumper wires.

1. Wire the IR module: **VCC → 5V, GND → GND, OUT → pin 2**.
2. Upload this code:

~~~
const int IR = 2, LED = 13;   // LED 13 is built into the Arduino

void setup() { pinMode(IR, INPUT); pinMode(LED, OUTPUT); Serial.begin(9600); }

void loop() {
  int seen = digitalRead(IR);
  Serial.println(seen);            // watch it in Tools → Serial Monitor
  digitalWrite(LED, seen == HIGH ? HIGH : LOW);   // HIGH = black line on most modules
  delay(50);
}
~~~

3. Hold the sensor over white paper, then over the black line. Watch the light and the Serial Monitor.

> If it's the wrong way round on your module, swap HIGH and LOW in the code. That's **diagnosing**!

### 📊 Measure

How far above the paper can the sensor be and still see the line?

| Height | Sees black? | Sees white? |
|---|---|---|
| 0.5 cm | | |
| 1 cm | | |
| 2 cm | | |
| 3 cm | | |

### 🔄 Improve it

Turn the little screw (potentiometer) on the module. Does the best height change?

![A rover drives from A to B around obstacles](https://tinkerwith.me/assets/courses/young-engineers/rover-challenge.svg)

**Next step:** with two sensors and two motors, this becomes a real line-following robot, like the ones in our live courses.

⭐ **Engineer move unlocked: requirements!** Before you build, write what "success" means, like: *"sees the line at 1 cm, 10 out of 10 times."*$tw$, $tw$[{"q": "A line follower's left sensor sees the line. What should it do?", "options": ["Turn left", "Turn right", "Stop forever"], "answer": 0}, {"q": "Why measure the sensor at different heights?", "options": ["To find where it works reliably", "To make it look neat", "It's not needed"], "answer": 0}, {"q": "Which is a good, measurable requirement?", "options": ["It should be good", "Sees the line at 1 cm, 10 out of 10 times", "It should try hard"], "answer": 1}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 12, $tw$Ages 11–13: Junior Engineers$tw$, $tw$Challenge: the waste-sorting machine$tw$, $tw$## ♻️ Challenge: the waste-sorting machine

Real engineers start with **requirements**: what must the solution do? Today you'll write them, then build to meet them.

![A cardboard ramp with a hole sorts small and big items into two bins](https://tinkerwith.me/assets/courses/young-engineers/sorter.svg)

⏱️ 90 minutes

**You need:** a long piece of cardboard (ramp), 2 boxes or bins, scissors, tape, books to prop the ramp, small and big items to sort (bottle tops and small balls, or beans and marbles).

### Step 1: requirements

Copy and complete in your notebook:

- It must sort **2 sizes** of items.
- It must be right at least **__ out of 10** times.
- It must fit on a **desk**.
- It must use only **free materials**.

### Step 2: design and build

1. Prop the ramp on books so items roll down.
2. Cut a **hole** in the ramp just bigger than the small items, but smaller than the big ones.
3. Put the "small" bin under the hole and the "big" bin at the end of the ramp.

### 📊 Step 3: test with data

Roll 10 items (5 small, 5 big). Count the correct ones.

| Test | Correct out of 10 | Meets requirement? |
|---|---|---|
| 1 | | |
| 2 (after a change) | | |

### 🔍 Diagnose and improve

Do big items fall in the hole? Do small ones skip over it? Try **one** change: ramp angle, hole shape, adding a "bump" before the hole.

### 🧰 Kit extension: an automatic gate

With the [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html): a servo motor can open a gate to sort items. Wire the servo **brown → GND, red → 5V, orange → pin 9**, and a button to **pin 2 and GND**:

~~~
#include <Servo.h>
Servo gate;
const int BUTTON = 2;

void setup() { gate.attach(9); pinMode(BUTTON, INPUT_PULLUP); gate.write(0); }

void loop() {
  if (digitalRead(BUTTON) == LOW) { gate.write(90); delay(1500); gate.write(0); }
}
~~~

### 🌍 Engineers in real life

Recycling plants sort waste with screens, magnets, air jets and cameras, and engineers in Kenya are building sorting machines to keep plastic out of rivers.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain$tw$, $tw$[{"q": "When should you write the requirements?", "options": ["Before you build", "After testing", "Never"], "answer": 0}, {"q": "Your sorter gets 6 out of 10 right, but the requirement is 8. What next?", "options": ["Diagnose, change one thing and test again", "Change the requirement to 6", "Give up"], "answer": 0}, {"q": "What makes the small items fall through?", "options": ["The hole is bigger than small items but smaller than big ones", "The ramp is blue", "Magnets"], "answer": 0}]$tw$::jsonb, false);
end $$;

-- PART 3 of 3: lessons 13-18
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'young-engineers';
  if cid is null then raise exception 'Run part 1 first.'; end if;
  delete from public.lms_lessons where course_id = cid and position between 13 and 18;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 13, $tw$Ages 14–16: Engineers$tw$, $tw$Experiment: paper helicopter trade-offs$tw$, $tw$## ⚙️ Engineers (ages 14–16)

Engineers balance **trade-offs**: improving one thing often makes another worse. Today you'll prove it with data.

![Three paper helicopters with different wing lengths and a bar chart of fall times](https://tinkerwith.me/assets/courses/young-engineers/paper-helicopter.svg)

⏱️ 60 minutes

**You need:** paper, scissors, paper clips, a ruler, a stopwatch, a spreadsheet (Google Sheets is free).

### Build

1. Cut a strip 5 cm × 20 cm. Cut down the middle from the top for **6 cm**: these are the wings.
2. Fold one wing forward, one back.
3. Fold the bottom up and add a paper clip.
4. Make two more with **9 cm** and **12 cm** wings.

### 📊 The experiment

Drop each from **2 m** (stand on a safe step, with a grown-up). Time it **5 times**.

| Wing length | T1 | T2 | T3 | T4 | T5 | Average | Spins steadily? |
|---|---|---|---|---|---|---|---|
| 6 cm | | | | | | | |
| 9 cm | | | | | | | |
| 12 cm | | | | | | | |

Put the data in Google Sheets, use **=AVERAGE()**, and make a **bar chart**.

### 🔍 Analyse

- Which falls slowest? Which is most **stable**?
- Is there a **trade-off** between slow and stable?
- What about adding a second paper clip?

### The trade-off

![Trade-offs between speed, accuracy, cost and battery life](https://tinkerwith.me/assets/courses/young-engineers/trade-offs.svg)

Every design has trade-offs: speed vs battery, cost vs accuracy. Write 3 sentences in your notebook: **what you gave up, what you gained, and why**.

⭐ **Engineer move unlocked: optimisation!**$tw$, $tw$[{"q": "What is a trade-off?", "options": ["Giving up some of one thing to gain another", "Swapping parts with a friend", "A type of sensor"], "answer": 0}, {"q": "Why time each helicopter 5 times?", "options": ["To get a reliable average", "Because 5 is lucky", "To tire it out"], "answer": 0}, {"q": "Which spreadsheet formula gives the mean of 5 times?", "options": ["=AVERAGE()", "=SUM()", "=COUNT()"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 14, $tw$Ages 14–16: Engineers$tw$, $tw$Build: an AI that sees$tw$, $tw$## 👁️ Build: an AI that sees

**Computer vision** lets machines recognise what a camera sees. Today you'll train one, then test it like an engineer.

⏱️ 60 minutes · 💻 Computer with a webcam

### Steps

1. Go to [Teachable Machine](https://teachablemachine.withgoogle.com/) → **Get started** → **Image project → Standard image model**.
2. Make 3 classes: **Plastic bottle**, **Paper**, **Nothing**.
3. For each class, record about **50 pictures** with the webcam (hold the item at different angles).
4. Click **Train model**, then test it with new items.

> 🔒 Your pictures stay in your browser unless you choose to save or share them.

### 📊 Test with data: the confusion table

Show it 10 items of each type and record what it **guessed**:

| Real item ↓ / AI guessed → | Plastic | Paper | Nothing |
|---|---|---|---|
| Plastic (10) | | | |
| Paper (10) | | | |
| Nothing (10) | | | |

**Accuracy** = correct guesses ÷ 30 × 100%.

### 🔍 Failure analysis

- Which mistakes did it make most? Why? (Lighting? Background? Too few examples?)
- Add more examples of the hard cases and retrain. Did accuracy improve?

### 🔗 Connect the systems

How could this AI work with your **waste-sorting machine** from the last stage? Draw the full system: camera → AI → servo gate → bins.

### 🌍 Engineers in real life

Farmers in Kenya use phone apps with computer vision to spot crop diseases from a photo of a leaf.$tw$, $tw$[{"q": "What is computer vision?", "options": ["Machines recognising what a camera sees", "A type of glasses", "A screen brightness setting"], "answer": 0}, {"q": "Your AI keeps confusing paper and plastic. What's a good fix?", "options": ["Add more examples of those items and retrain", "Delete the model", "Use a smaller screen"], "answer": 0}, {"q": "Accuracy is…", "options": ["Correct guesses divided by total guesses", "The number of classes", "How fast it trains"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 15, $tw$Ages 14–16: Engineers$tw$, $tw$Build: the smart streetlight$tw$, $tw$## 🌃 Build: the smart streetlight

Smart cities save energy. Your streetlight only switches on **when it's dark AND someone is there**.

![A streetlight that only switches on when it is dark and someone walks past](https://tinkerwith.me/assets/courses/young-engineers/streetlight.svg)

⏱️ 75 minutes · 🧰 [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html), or [Tinkercad Circuits](https://www.tinkercad.com/circuits) (free, in a browser, with a grown-up's account)

**You need:** Arduino, breadboard, LDR (light sensor) + 10 kΩ resistor, PIR motion sensor, white LED + 220 Ω resistor, jumper wires.

### Wiring

1. **LDR:** one leg to **5V**, the other to **A0**. A 10 kΩ resistor goes from **A0 to GND**.
2. **PIR:** VCC → **5V**, GND → **GND**, OUT → **pin 7**.
3. **LED:** long leg → 220 Ω resistor → **pin 9**; short leg → **GND**.

### The code

~~~
const int LDR = A0, PIR = 7, LAMP = 9;
int DARK = 400;   // change this after you measure!

void setup() { pinMode(PIR, INPUT); pinMode(LAMP, OUTPUT); Serial.begin(9600); }

void loop() {
  int light = analogRead(LDR);              // darker = smaller number
  bool someone = digitalRead(PIR) == HIGH;
  Serial.println(light);
  if (light < DARK && someone) digitalWrite(LAMP, HIGH);
  else digitalWrite(LAMP, LOW);
  delay(200);
}
~~~

### 📊 Calibrate with data

Open the Serial Monitor and record the readings:

| Condition | LDR reading |
|---|---|
| Room light on | |
| Room light off | |
| Covered with your hand | |

Set **DARK** halfway between "light" and "dark". That's **calibration**.

### 🔍 Trade-offs and improvements

- The PIR sensor takes a few seconds to reset. Is that a problem for a real street?
- Add a **delay** so the light stays on for 10 seconds after someone passes. What's the energy trade-off?
- **Estimate the savings:** if a streetlight is on 12 hours a night but people pass for only 2 hours, how much energy could it save?

### 🌍 Engineers in real life

Cities are switching to sensor-controlled LED streetlights to cut electricity bills and light pollution.

⭐ **Engineer move unlocked: calibration!**$tw$, $tw$[{"q": "Why does the streetlight check BOTH the LDR and the PIR?", "options": ["To save energy: only on when it's dark and someone is there", "Because one sensor is broken", "To make it brighter"], "answer": 0}, {"q": "Setting the DARK value from measured readings is called…", "options": ["Calibration", "Guessing", "Compiling"], "answer": 0}, {"q": "With the LDR wired to 5V and the resistor to GND, what happens to the reading when it gets darker?", "options": ["It gets smaller", "It gets bigger", "It stays the same"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 16, $tw$Ages 16–18: Engineering Innovators$tw$, $tw$Capstone part 1: find a real problem$tw$, $tw$## 🚀 Engineering Innovators (ages 16–18)

Innovators solve **real problems for real people**. Your capstone runs over the next two lessons.

![Community problems a capstone can solve](https://tinkerwith.me/assets/courses/young-engineers/capstone.svg)

⏱️ 2–3 hours over a week

### Choose a pathway

Robotics and Automation · AI and Computer Vision · Embedded Systems · Mechanical Design · Drones and Autonomous Systems · Biomedical Engineering · Smart Cities / IoT

### Step 1: spot problems

List 10 problems you've noticed in your community: water, farming, accessibility, waste, transport, safety or education. Circle the 3 you care about most.

### Step 2: interview a real user

Talk to someone who **lives with the problem**: a farmer, a shopkeeper, a teacher, a neighbour. Ask:

1. Tell me about the last time this problem happened.
2. What do you do about it now?
3. What's the hardest part?
4. If you could wave a magic wand, what would change?
5. Can I show you my idea later?

> Listen more than you talk. Don't pitch your idea yet!

### Step 3: write the problem statement

*"[User] needs a way to [need] because [insight from the interview]."*

For example: *"Small-scale farmers in Kiambu need a way to know when to water their crops because they waste water guessing."*

### Step 4: requirements

Write 5 measurable requirements, like *"costs under KES 2,000"* or *"works without Wi-Fi"*.$tw$, $tw$[{"q": "What is the first step of a capstone project?", "options": ["Build the system", "Identify a real problem", "Present the solution"], "answer": 1}, {"q": "In a user interview, you should mostly…", "options": ["Listen and ask about real experiences", "Pitch your idea", "Talk about yourself"], "answer": 0}, {"q": "Which is a measurable requirement?", "options": ["It should be cheap", "Costs under KES 2,000", "It should be cool"], "answer": 1}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 17, $tw$Ages 16–18: Engineering Innovators$tw$, $tw$Capstone part 2: prototype, test and pitch$tw$, $tw$## 🛠️ Capstone part 2: prototype, test and pitch

### Step 5: ideas and design

Sketch **3 different** solutions. Score each against your requirements (1–5). Pick the best and draw it in detail, with a parts list and costs.

### Step 6: build a prototype

Start rough and cheap: cardboard, the [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html), a spreadsheet, or an app mock-up on paper. A prototype answers **one question**: *will this work?*

### Step 7: test with data

| Requirement | Target | Result | Pass? |
|---|---|---|---|
| | | | |
| | | | |

Show it to your user. What did they say? What surprised you?

### Step 8: iterate

Use the Tinker Loop again. Improve one thing at a time, and keep notes of every version.

### Step 9: the pitch (3 minutes)

1. **The problem** and who has it (use a quote from your user).
2. **Your solution**, with a photo or a demo.
3. **The evidence**: your test data.
4. **What's next**: what you'd build with more time or money.

Record it on a phone, or present it to your family, class or school.

### 🌍 Innovators in real life

Many young African engineers have started this way: noticing a problem, building a simple prototype, testing it with real users, and growing it into a business or a solution for their whole community.

⭐ **Engineer move unlocked: innovation!**

📸 **Share your build:** send a photo or a few words on our [Share your story](https://tinkerwith.me/stories.html) page.$tw$, $tw$[{"q": "A prototype's main job is to…", "options": ["Answer a question: will this work?", "Look finished", "Be expensive"], "answer": 0}, {"q": "How do you prove your solution works?", "options": ["Test it against the requirements with data", "Say it works", "Make it look professional"], "answer": 0}, {"q": "What should a good pitch include?", "options": ["The problem, the solution, the evidence and what's next", "Only the price", "A long list of parts"], "answer": 0}]$tw$::jsonb, false);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview) values (cid, 18, $tw$Your toolkit$tw$, $tw$The Engineer's Notebook and what's next$tw$, $tw$## 📓 The Engineer's Notebook

![The 9 steps of the Engineer's Notebook](https://tinkerwith.me/assets/courses/young-engineers/notebook.svg)

Use this template for every build from now on:

| Step | Ask yourself |
|---|---|
| 1. Problem | What are we trying to solve? |
| 2. Requirements | What must the solution do? |
| 3. Ideas | What could we build? |
| 4. Design | Draw it. Model it. Explain it. |
| 5. Build | Create the prototype. |
| 6. Test | What happened? |
| 7. Data | What did we measure? |
| 8. Improve | What will we change? |
| 9. Explain | Can someone else understand the solution? |

## 🏆 What a young engineer can do

- Turn a real-world problem into an engineering challenge.
- Design a solution within constraints.
- Use maths and science to make predictions.
- Build with mechanical, electronic and digital parts.
- Program a machine to sense, decide and act.
- Test systematically and use data to improve a design.
- Work safely and ethically, and explain technical work clearly.

## 🚀 What's next?

- **Build with a trainer:** our [live courses](https://tinkerwith.me/courses.html) take these builds further: smart homes, self-driving cars, robot arms and AI projects.
- **Get the kit:** the [Tinkerwith Maker Kit](https://tinkerwith.me/courses.html) is used in every Arduino course.
- **Keep learning online:** try the [AI Beginners Workbook](https://tinkerwith.me/course.html?c=ai-beginners-workbook) and build your own chatbot.

## 🎓 The destination

The goal isn't simply to know Arduino, Python or robotics.

**We want young people who see a problem and think: "I can figure this out."**

Robotics is the playground. Engineering is the mindset. Innovation is the outcome.

📸 **Share your build:** send a photo or a few words on our [Share your story](https://tinkerwith.me/stories.html) page.$tw$, $tw$[{"q": "In the Engineer's Notebook, what comes right after Test?", "options": ["Data", "Ideas", "Problem"], "answer": 0}, {"q": "What is the main goal of Young Engineers?", "options": ["Memorising Arduino code", "Young people who think \"I can figure this out\"", "Winning every competition"], "answer": 1}, {"q": "Why keep an Engineer's Notebook?", "options": ["So you and others can follow, repeat and improve the work", "Teachers like neat books", "It replaces testing"], "answer": 0}]$tw$::jsonb, false);
end $$;
