-- Young Engineers: rebuilt from the SCORM 1.2 package
-- "TinkerWith.Me Young Engineers" (content/index.html) as a normal course.
-- Run once in Supabase → SQL Editor (after lms.sql). Saved as a DRAFT:
-- review it in teach.html and publish it there. Skipped if the slug exists.

do $$
declare cid uuid;
begin
  if exists (select 1 from public.lms_courses where slug = 'young-engineers') then return; end if;
  insert into public.lms_courses (slug, title, summary, description, age_range, price_kes, is_published, position)
  values ('young-engineers', $tw$Young Engineers$tw$, $tw$From curious kids to problem-solving engineers: the Tinker Loop, the 8 engineering superpowers and a hands-on challenge for every age stage.$tw$, $tw$**Robotics is our playground. Engineering is the superpower.**

Engineering isn't about getting everything right the first time. It's about asking great questions, making things, testing them, learning from failure and making them better.

In this course you will:

- learn the **Tinker Loop**, the way engineers work
- discover the **8 engineering superpowers**
- follow the **Young Engineer Journey** from age 5 to 18, with a hands-on challenge at every stage
- start your own **Engineer's Notebook**

Families can take it together: younger children with a parent, older learners on their own. Each lesson ends with a short quiz.$tw$, '5–18', 12000, false, 5)
  returning id into cid;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 1, $tw$Start here$tw$, $tw$Your mission: the Tinker Loop$tw$, $tw$## 🎯 Your mission

Engineering isn't about getting everything right the first time. It's about asking great questions, making things, testing them, learning from failure and making them better.

### The Tinker Loop

This is how engineers work, every time:

🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

1. **Think**: what is the problem?
2. **Design**: plan a solution.
3. **Build**: make it.
4. **Test**: try it out.
5. **Measure**: collect evidence instead of guessing.
6. **Diagnose**: work out why it did (or didn't) work.
7. **Improve**: change one thing and try again.
8. **Explain**: share what you made so others can understand it.

> When something fails, that isn't the end. **Failure is data.** Ask: *What happened? What changed? What does the evidence tell us?*$tw$, $tw$[{"q": "Your robot fails its test. What should an engineer do first?", "options": ["Throw it away", "Investigate why it failed", "Blame the robot"], "answer": 1}, {"q": "Which step comes straight after Build in the Tinker Loop?", "options": ["Explain", "Think", "Test"], "answer": 2}, {"q": "What does \"failure is data\" mean?", "options": ["A failed test tells you something useful", "Failing means you should stop", "Computers store failures"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 2, $tw$Start here$tw$, $tw$The Young Engineer Journey$tw$, $tw$## 🗺️ The Young Engineer Journey

Every engineer grows through stages. Find yours!

| Stage | Age | Engineer identity | Big question |
|---|---|---|---|
| 🌱 Engineering Explorer | 5–7 | I can make things. | What can I build? |
| 🔧 Junior Maker | 8–10 | I can solve problems. | How can I make it work? |
| 🤖 Junior Engineer | 11–13 | I can design systems. | How can I design it better? |
| ⚙️ Engineer | 14–16 | I can engineer solutions. | Why does it work? |
| 🚀 Engineering Innovator | 16–18 | I can create solutions. | How can I solve a real problem? |

The next lessons visit each stage, with a challenge for each. Start with your own stage, and peek at the next one to see where you're heading.$tw$, $tw$[{"q": "Which stage asks the big question \"How can I make it work?\"", "options": ["Engineering Explorer", "Junior Maker", "Engineering Innovator"], "answer": 1}, {"q": "What is the engineer identity of a Junior Engineer (11–13)?", "options": ["I can design systems.", "I can make things.", "I can create solutions."], "answer": 0}, {"q": "Which stage is about solving real problems in the world?", "options": ["Junior Maker", "Engineer", "Engineering Innovator"], "answer": 2}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 3, $tw$Start here$tw$, $tw$The 8 engineering superpowers$tw$, $tw$## 🧩 The 8 engineering superpowers

Engineers combine many skills. These are the 8 superpowers you'll build up through every stage:

1. **Design**: turn a problem into a plan.
2. **Maths**: measure, calculate, compare and predict.
3. **Science**: understand forces, energy, motion and electricity.
4. **Electronics**: make sensors, motors and circuits work together.
5. **Code + AI**: give machines instructions and intelligence.
6. **CAD + Making**: design before you build; fabricate your ideas.
7. **Test + Data**: measure performance instead of guessing.
8. **Communicate**: explain your design so others can build on it.

### Try this
Think of something you built or fixed recently. Which superpowers did you use?$tw$, $tw$[{"q": "Which superpower is about measuring performance instead of guessing?", "options": ["Design", "Test + Data", "Communicate"], "answer": 1}, {"q": "\"Give machines instructions and intelligence\" describes which superpower?", "options": ["Code + AI", "Science", "Maths"], "answer": 0}, {"q": "Why does an engineer need to Communicate?", "options": ["To make the robot faster", "So others can understand and build on the design", "Because it's the last step of school"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 4, $tw$The stages$tw$, $tw$Ages 5–7: Engineering Explorers$tw$, $tw$## 🌱 Ages 5–7: Engineering Explorers

**How learners think at this stage:** concrete, playful, sensory, short challenges and lots of repetition.

### What you learn
- Shapes and patterns
- Push/pull and balance
- Simple machines
- Basic circuits
- Sequencing
- Measurement

### What you build
- A bridge that holds blocks
- A moving toy
- A light-up invention
- A simple robot

### 🚧 Challenge: The Bridge Builder
Build a bridge from simple materials such as paper, cardboard, sticks or tape. Can it hold 10 blocks? **Change one thing and test again.** Did it hold more or fewer blocks?

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

When you've done it, you've unlocked a new engineer move: ⭐ **test and improve**!$tw$, $tw$[{"q": "Your bridge holds 6 blocks. What should you do next?", "options": ["Give up", "Change one thing and test again", "Change everything at once"], "answer": 1}, {"q": "Why change only one thing at a time?", "options": ["So you know what made the difference", "Because it's faster", "So the bridge looks nicer"], "answer": 0}, {"q": "Which of these do Engineering Explorers learn?", "options": ["Trigonometry", "Push/pull and balance", "Computer vision"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 5, $tw$The stages$tw$, $tw$Ages 8–10: Junior Makers$tw$, $tw$## 🔧 Ages 8–10: Junior Makers

**How learners think at this stage:** increasingly logical and independent; ready for rules, constraints, measurement and simple experiments.

### What you learn
- The engineering design cycle
- Scratch and algorithms
- Arduino basics
- Sensors and motors
- Ratios and measurement
- Simple CAD

### What you build
- Obstacle robot
- Smart traffic light
- Automatic plant watering
- Robotic vehicle
- Mini conveyor

### 🚦 Challenge: Smart Traffic
Design a traffic light that knows when something is waiting. Add a sensor. **What happens if the sensor gives the wrong reading?** How could you find out, and how could you fix it?

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

When you've done it, you've unlocked a new engineer move: ⭐ **measure instead of guess**!$tw$, $tw$[{"q": "What does the sensor add to a smart traffic light?", "options": ["It knows when something is waiting", "It makes the lights brighter", "It plays music"], "answer": 0}, {"q": "Your sensor sometimes gives the wrong reading. What's the engineer move?", "options": ["Ignore it", "Measure and test to find out when and why", "Remove the sensor"], "answer": 1}, {"q": "Which of these do Junior Makers learn?", "options": ["Arduino basics", "Failure analysis for drones", "Biomedical engineering"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 6, $tw$The stages$tw$, $tw$Ages 11–13: Junior Engineers$tw$, $tw$## 🤖 Ages 11–13: Junior Engineers

**How learners think at this stage:** ready for abstraction, systems, cause-and-effect, structured projects and evidence-based decisions.

### What you learn
- Requirements and constraints
- Arduino + Python
- Forces, motion and energy
- Circuits and motors
- Algebra, ratios and graphs
- CAD and 3D design
- Data collection

### What you build
- Autonomous rover
- Robotic arm
- Smart home
- Line follower
- Waste-sorting robot
- Mini factory

### 🤖 Challenge: Autonomous Rover
Give your rover a mission: travel from A to B while avoiding obstacles. **Define success before you build.** For example: "reaches B in under 30 seconds without touching an obstacle, 4 times out of 5."

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

When you've done it, you've unlocked a new engineer move: ⭐ **requirements**!$tw$, $tw$[{"q": "When should you define what success looks like?", "options": ["After testing", "Before you build", "Only if it fails"], "answer": 1}, {"q": "Which is a good, measurable requirement?", "options": ["The rover should be cool", "Reaches B in under 30 seconds, 4 times out of 5", "The rover should try its best"], "answer": 1}, {"q": "What are constraints?", "options": ["Limits your design must work within", "Extra parts", "Mistakes in the code"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 7, $tw$The stages$tw$, $tw$Ages 14–16: Engineers$tw$, $tw$## ⚙️ Ages 14–16: Engineers

**How learners think at this stage:** ready for formal theory, trade-offs, multi-step projects, technical documentation and independent troubleshooting.

### What you learn
- Systems engineering
- Algebra, trigonometry and statistics
- Mechanics and electricity
- Python / C++
- Raspberry Pi
- CAD, 3D printing and fabrication
- Computer vision
- Failure analysis

### What you engineer
- Autonomous vehicle
- Vision-guided robot
- Drone system
- Smart-city system
- Assistive technology

### 🏁 Challenge: Autonomous Vehicle
Design a robot that navigates a course. You have constraints on **speed, accuracy, cost and battery**. Which trade-offs will you make? Write down what you gave up, what you gained, and why.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

When you've done it, you've unlocked a new engineer move: ⭐ **optimisation**!$tw$, $tw$[{"q": "What is a trade-off?", "options": ["Giving up some of one thing to gain another", "Swapping parts with a friend", "A type of sensor"], "answer": 0}, {"q": "Making your vehicle faster drains the battery quicker. This is an example of…", "options": ["A bug", "A trade-off", "A requirement"], "answer": 1}, {"q": "Why write down your trade-offs?", "options": ["So others understand your design decisions", "To make the project longer", "It isn't needed"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 8, $tw$The stages$tw$, $tw$Ages 16–18: Engineering Innovators$tw$, $tw$## 🚀 Ages 16–18: Engineering Innovators

**How learners think at this stage:** ready for specialisation, research, complex systems, ambiguity and independent capstone work.

### Choose a pathway
- Robotics and Automation
- AI and Computer Vision
- Embedded Systems
- Mechanical Design
- Drones and Autonomous Systems
- Biomedical Engineering
- Smart Cities / IoT

### Your capstone, step by step
1. Identify a real problem
2. Research users and context
3. Define requirements
4. Design and prototype
5. Build the system
6. Test with data
7. Iterate
8. Present the solution

### 🌍 Grand Challenge: Build for the Real World
Pick a problem in your community: water, farming, accessibility, waste, transport, safety or education. Engineer a solution and **prove that it works**. Make sure your capstone has a real user you can talk to.

Use the Tinker Loop: 🧠 Think → ✏️ Design → 🔨 Build → 🧪 Test → 📊 Measure → 🔍 Diagnose → 🔄 Improve → 🗣️ Explain

When you've done it, you've unlocked a new engineer move: ⭐ **innovation**!$tw$, $tw$[{"q": "What is the first step of a capstone project?", "options": ["Build the system", "Identify a real problem", "Present the solution"], "answer": 1}, {"q": "Why should a capstone have a real user?", "options": ["So the solution solves a real need", "To get more marks", "Users build it for you"], "answer": 0}, {"q": "How do you prove your solution works?", "options": ["Say it works", "Test it with data", "Make it look professional"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 9, $tw$Your toolkit$tw$, $tw$The Engineer's Notebook and what's next$tw$, $tw$## 📓 The Engineer's Notebook

Every serious project can use this simple template. Copy it into a notebook and fill it in for your next build:

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

## 🏆 What a young engineer can eventually do

- Turn a real-world problem into an engineering challenge.
- Design a solution within constraints.
- Use maths and science to make predictions.
- Build with mechanical, electronic and digital components.
- Program a machine to sense, decide and act.
- Use CAD and fabrication tools to make parts.
- Test systematically and use data to improve a design.
- Work safely and ethically.
- Document and communicate technical work.
- Build a portfolio of increasingly complex projects.

## 🎓 The destination

The goal isn't simply to know Arduino, Python or robotics.

**We want young people who see a problem and think: "I can figure this out."**

Robotics is the playground. Engineering is the mindset. Innovation is the outcome.$tw$, $tw$[{"q": "In the Engineer's Notebook, what comes right after Test?", "options": ["Data", "Ideas", "Problem"], "answer": 0}, {"q": "What is the main goal of the Young Engineers pathway?", "options": ["Memorising Arduino code", "Young people who think \"I can figure this out\"", "Winning every competition"], "answer": 1}, {"q": "Why write things down in an Engineer's Notebook?", "options": ["So you and others can follow, repeat and improve the work", "Teachers like neat books", "It replaces testing"], "answer": 0}]$tw$::jsonb);
end $$;
