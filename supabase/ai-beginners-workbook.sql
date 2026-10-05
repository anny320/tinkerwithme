-- AI Beginners Workbook: the full course, rebuilt from the original workbook
-- (AI Workbook for Kids in Africa + the "Build Your First AI Chatbot" project).
-- 14 lessons, each with an activity and a quiz. Illustrations in assets/courses/ai-workbook/.
-- Run in Supabase -> SQL Editor, in 3 parts (run each separately, in order).
-- Each part is safe to run more than once. It keeps the course's link, cover,
-- enrolments and publish setting, sets the price to KES 3,000 / US$39, and
-- replaces all its lessons (lesson ticks on the old lessons reset).

-- PART 1 of 3: course details + lessons 1-5
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'ai-beginners-workbook';
  if cid is null then
    insert into public.lms_courses (slug, title, cover_url, is_published, position)
      values ('ai-beginners-workbook', 'AI Beginners Workbook', 'https://tinkerwith.me/wp-content/uploads/2026/03/ai-images.jpg', false, 3)
      returning id into cid;
  end if;
  update public.lms_courses set
    summary = $tw$Discover what AI is, where it's used across Africa, the jobs it's creating, and how to use it creatively and safely. Then build your own chatbot in Scratch and train an AI with Teachable Machine.$tw$,
    description = $tw$Hello and welcome to your very own **AI Workbook**! This course helps children understand **Artificial Intelligence (AI)**, the technology that lets machines learn, solve problems and make decisions, and shows them how to use it to create, learn and help their community.

**What your child will do**

- Find out what AI is, and spot it in everyday life in Kenya and across Africa
- Meet the AI jobs of the future, and the African innovators already doing them
- Make art, music and stories with AI tools (together with a grown-up)
- Use AI as a learning buddy for research and coding, and check its answers
- Learn the golden rules for using AI **safely, fairly and kindly**
- **Final project:** build a chatbot in Scratch and train an AI to recognise faces with Teachable Machine

**How it works**

- 14 short lessons of about 20–40 minutes, each with a hands-on activity and a quick quiz
- Free tools only: a computer or tablet with a web browser (a webcam helps for the last project)
- Younger learners (8–10) do best with a grown-up nearby; older learners (11–14) can go on their own
- Earn a Tinkerwith certificate when you finish$tw$,
    age_range = '8–14', price_kes = 3000, price_usd = 39, updated_at = now()
  where id = cid;
  delete from public.lms_lessons where course_id = cid;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 1, $tw$Start here$tw$, $tw$Welcome to your AI Workbook$tw$, $tw$## 👋 Welcome!

This workbook will help you learn about **Artificial Intelligence (AI)**, the technology that lets machines learn and act in ways that seem smart.

### What we'll explore

- What AI is and why it matters in Africa
- Creative ways to use AI for art, music and stories
- How AI can help you with research and coding
- How to stay **safe and ethical** when using AI tools
- **Final project:** build your own chatbot and train an AI!

### Why should kids in Africa learn about AI?

- AI is already used in **banks, phones, hospitals and farms** to help produce more food.
- Understanding AI opens up exciting **career opportunities**.
- You can use AI to **create solutions for your community**.

### What you need

- A computer or tablet with a web browser
- A notebook and pencil (your **AI Journal**)
- A grown-up nearby for the lessons that use online AI tools

> 💡 **Tip for grown-ups:** most AI chat and image tools are made for ages 13 and up. Younger learners should use them together with you, on your account.

### How to use this course

Take **one lesson at a time**. Each lesson has something to read, an **activity** to do, and a short **quiz**. Take breaks: learning sticks better that way!

### ✏️ Activity: start your AI Journal

On the first page of your notebook, write:

1. Your name and today's date
2. One thing you think AI can do
3. One question you have about AI

You'll look back at this page at the end of the course.$tw$, $tw$[{"q": "What does AI stand for?", "options": ["Automatic Internet", "Artificial Intelligence", "Amazing Ideas"], "answer": 1}, {"q": "Which of these is a way AI is used in Africa?", "options": ["Helping farmers grow more food", "Making the sun rise", "Growing taller trees by magic"], "answer": 0}, {"q": "What should younger learners do before using an online AI tool?", "options": ["Use it alone, secretly", "Ask a grown-up to use it with them", "Share their password"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 2, $tw$Chapter 1: What is AI?$tw$, $tw$What is Artificial Intelligence?$tw$, $tw$## 🤖 What is AI?

AI is like **teaching a computer or a robot to learn, solve problems or make decisions**. Think of it as a very smart helper that can do some tasks faster, or differently, than humans can.

![How AI learns: data, algorithm, machine learning, answer](https://tinkerwith.me/assets/courses/ai-workbook/how-ai-learns.svg)

### Three key words

- **Data**: information we give to AI systems, like pictures, words, sounds or numbers.
- **Algorithm**: a set of rules or steps a computer follows to solve a problem.
- **Machine learning**: the part of AI where computers **learn from data**, finding patterns in lots of examples.

### An example

If you show a computer **thousands of pictures of cats and dogs**, it starts to notice patterns (pointy ears, long snouts, whiskers). Then, when you show it a new picture, it can make a **smart guess**: "That's a cat!"

AI doesn't *think* like you do. It's very good at spotting patterns, but it can still make mistakes.

### ✏️ Activity: be the algorithm

An algorithm is just a list of steps. Write the steps for **making a cup of tea** (or a sandwich) in your AI Journal.

1. Write each step on its own line.
2. Ask someone to follow your steps **exactly**, word for word.
3. Did anything go wrong? Maybe you forgot "open the tap"! Fix your algorithm and try again.

Computers need very clear steps too. That's what programmers write!$tw$, $tw$[{"q": "What is an algorithm?", "options": ["A type of robot", "A set of steps to solve a problem", "A computer screen"], "answer": 1}, {"q": "How does machine learning work?", "options": ["The computer learns patterns from lots of examples", "The computer reads your mind", "Someone types every answer in"], "answer": 0}, {"q": "Which of these is data?", "options": ["Photos of cats and dogs", "A computer's power button", "The internet cable"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 3, $tw$Chapter 1: What is AI?$tw$, $tw$AI all around us$tw$, $tw$## 🔍 Spot the AI around you

You probably use AI every day without noticing!

![Chatbots, recommendations, voice assistants and farm drones](https://tinkerwith.me/assets/courses/ai-workbook/ai-around-us.svg)

### Real-life examples

- **Chatbots** answer customer questions online, like the help chat on a bank or phone company app.
- **Recommendation systems** suggest your next video or song on YouTube, Spotify or Netflix.
- **Voice assistants** like Google Assistant and Siri understand what you say.
- **Maps** suggest the fastest route around traffic.
- **Phone cameras** find faces and make photos look better.

### 🌍 Fun facts about AI in Africa

- Researchers across Africa, like the **Masakhane** community, are using AI to help computers understand and translate **African languages** such as Kiswahili, Yoruba and isiZulu.
- **Self-flying drones** deliver blood and medicine to hospitals in remote areas of **Rwanda and Ghana**.
- Farmers can take a photo of a sick plant and an app uses AI to suggest what disease it might have.

### ✏️ Activity: AI spotting hunt

Walk around your home (or think about your day) and find **5 things that might use AI**. For each one, write in your AI Journal:

| Thing | What does the AI do? |
| --- | --- |
| e.g. YouTube | Suggests videos I might like |

Ask a grown-up: **"Which AI do you use at work?"**$tw$, $tw$[{"q": "What does a recommendation system do?", "options": ["Suggests videos or songs you might like", "Charges your phone", "Cooks food"], "answer": 0}, {"q": "How are drones helping hospitals in Rwanda and Ghana?", "options": ["Delivering blood and medicine", "Painting the walls", "Teaching lessons"], "answer": 0}, {"q": "Which of these uses AI?", "options": ["A voice assistant like Siri", "A wooden chair", "A paper book"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 4, $tw$Chapter 2: Careers in AI$tw$, $tw$AI careers: jobs of the future$tw$, $tw$## 💼 AI jobs of the future

AI is creating **brand-new jobs**, and many of them don't exist yet! Here are some you could do one day.

### Jobs that might interest you

| Career | What they do |
| --- | --- |
| **Game developer** | Use AI to make games more fun and challenging |
| **Robotics engineer** | Build and program robots |
| **Data scientist** | Study information to find patterns and answers |
| **Health technology specialist** | Use AI to help doctors find illnesses early |
| **Agricultural technologist** | Use AI, drones and sensors to help farmers grow more food |
| **AI ethicist** | Make sure AI is fair, safe and used responsibly |
| **AI artist** | Create art, music and animations with AI tools |
| **Prompt engineer** | Write clear instructions that help AI give useful results |

### More AI careers

| Career | What they do | Example work |
| --- | --- | --- |
| **Machine learning engineer** | Design systems that learn from data | Image recognition, fraud detection |
| **Computer vision engineer** | Help computers understand pictures and videos | Self-driving cars |
| **Language (NLP) engineer** | Help computers understand human language | Chatbots, translation tools |
| **Environmental data scientist** | Study climate data with AI | Predicting weather and floods |
| **AI policy specialist** | Help governments make rules for safe AI | AI laws |
| **AI education specialist** | Teach people how to use AI | Courses like this one! |

### Why AI is important in Africa

- **Healthcare:** AI can make health services faster and reach more people.
- **Education:** AI can give each learner personalised help.
- **Farming:** AI helps farmers deal with pests, disease and changing weather.
- **Jobs and business:** technology skills lead to new jobs and new businesses.

### ✏️ Activity: my future AI job card

Make a job card in your AI Journal:

1. **Job title** (choose one above, or invent your own!)
2. **What I would do** every day
3. **A problem in my community** this job could help solve
4. Draw yourself doing the job 🎨$tw$, $tw$[{"q": "What does a robotics engineer do?", "options": ["Builds and programs robots", "Grows crops by hand", "Writes newspapers"], "answer": 0}, {"q": "Who makes sure AI is fair and used responsibly?", "options": ["An AI ethicist", "A game developer", "A pilot"], "answer": 0}, {"q": "How can AI help farmers?", "options": ["By spotting pests and plant diseases", "By making it rain on demand", "It can't help farmers"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 5, $tw$Chapter 3: AI for creativity$tw$, $tw$Make art with generative AI$tw$, $tw$## 🎨 What is generative AI?

**Generative AI** is a type of AI that can **create new things**: pictures, music, stories or videos. You give it instructions in words, called a **prompt**, and it makes something new.

![A text prompt goes into an AI model, which draws a picture](https://tinkerwith.me/assets/courses/ai-workbook/prompt-to-picture.svg)

### By the end of this lesson you will be able to

1. Explain what generative AI is
2. Use a **text prompt** to make a picture
3. **Improve** your prompt to get a better picture

### Tools you can try (with a grown-up)

- **Canva** (Magic Media), **Microsoft Designer** or **Adobe Firefly**: type a description and get a picture.

> Most of these tools are for ages 13+, so use them on a grown-up's account, together.

### Writing a great prompt

A good prompt answers four questions:

- **Who or what?** a friendly robot
- **Doing what?** painting a sunset
- **Where?** over Mount Kenya
- **What style?** cartoon, watercolour, or 3D

> "A friendly robot painting a sunset over Mount Kenya, cartoon style"

### ✏️ Activity: create your own AI artwork

1. Write a simple prompt, like "a lion".
2. Make it better by adding **where** and **style**: "a lion wearing sunglasses in Nairobi National Park, cartoon style".
3. Try **3 versions** of your prompt. Which picture do you like best? Why?
4. Copy your best prompt into your AI Journal.

**Remember:** AI art is made from patterns in other people's art. Always say when a picture was made with AI.$tw$, $tw$[{"q": "What is a prompt?", "options": ["The words you give AI to tell it what to make", "A type of paintbrush", "A computer virus"], "answer": 0}, {"q": "Which prompt will probably give the best picture?", "options": ["lion", "a lion wearing sunglasses in Nairobi National Park, cartoon style", "picture"], "answer": 1}, {"q": "What should you do when you share a picture made with AI?", "options": ["Say it was made with AI", "Pretend you drew it by hand", "Sell it as your own painting"], "answer": 0}]$tw$::jsonb);
end $$;

-- PART 2 of 3: lessons 6-10
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'ai-beginners-workbook';
  if cid is null then raise exception 'Run part 1 first.'; end if;
  delete from public.lms_lessons where course_id = cid and position between 6 and 10;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 6, $tw$Chapter 3: AI for creativity$tw$, $tw$Music and stories with AI$tw$, $tw$## 🎵 Making music with AI

AI music tools can **compose new songs or beats**. You choose a style (like Afrobeats, gospel or calm piano) and describe a mood, and the AI creates a melody.

- Tools like **Suno** make full songs from a short description (with a grown-up's account).
- **Chrome Music Lab** (free, no account) is a fun place to make your own beats and melodies, so you can compare your music with AI music.

## 📖 Writing stories with AI

Some AI tools can help you write **stories, jokes or poems**. They are great for practising **Kiswahili, English** or other languages.

But **you** are the author! Use AI as a helper:

- Ask it for **ideas** when you're stuck
- Ask it to **check your spelling**
- Ask it for a **new word** that means "happy"

### ✏️ Activity: story with a twist

With a grown-up, ask an AI chat tool (like Gemini, ChatGPT or Copilot):

> "Help me start a 5-line story for kids about a robot who visits Lamu. Give me only the first 3 lines."

1. Read the 3 lines the AI wrote.
2. Write the **last 2 lines yourself**, with your own surprise ending!
3. Try asking for the story **in Kiswahili** too.
4. Draw a picture for your story in your AI Journal.

**Think about it:** which part of the story do you like best, the AI's part or yours?$tw$, $tw$[{"q": "What can AI music tools do?", "options": ["Compose new songs and beats", "Fix a broken guitar", "Sing at a real concert by themselves"], "answer": 0}, {"q": "When you write a story with AI, who is the author?", "options": ["The AI", "You are, and the AI is a helper", "Nobody"], "answer": 1}, {"q": "Which is a good way to use AI for writing?", "options": ["Ask it for ideas when you're stuck", "Copy everything and hand it in as yours", "Never read what it wrote"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 7, $tw$Chapter 4: AI for research and coding$tw$, $tw$AI as your learning and coding buddy$tw$, $tw$## 📚 How AI helps us learn

AI chat tools (like **Gemini**, **ChatGPT** or **Microsoft Copilot**) can answer questions on all kinds of topics. You can use them as a **reading buddy** that explains lessons in simpler words.

Try asking: *"Explain photosynthesis like I'm 9 years old."*

> ⚠️ AI can sound very sure and still be **wrong**. Always check important facts in a textbook, a trusted website, or with a teacher or parent.

## 💻 Coding with AI

- **Scratch** is a free, beginner-friendly way to code with blocks. You'll use it in the final project!
- **Code.org** has free lessons about how AI works, made for kids.
- Grown-up programmers use AI coding helpers like **GitHub Copilot** to suggest code.

## Kid-friendly coding activities

1. **Making a chatbot**: you'll build one in the final project.
2. **Predicting the weather**: see how AI learns patterns from data (activity below).

### ✏️ Activity 1: check the AI

With a grown-up, ask an AI tool to explain something you're learning at school. Then:

1. Write its answer in **one sentence** in your AI Journal.
2. Find the **same fact** in your textbook. Did they match? ✅ or ❌

### ✏️ Activity 2: be a weather predictor

AI learns patterns from data, and you can too!

1. Every morning for **5 days**, write the weather in your AI Journal: ☀️ sunny, ⛅ cloudy or 🌧️ rainy, and how hot it feels.
2. On day 6, look at your data and **predict** tomorrow's weather.
3. Were you right? Weather forecasters use AI to do this with millions of numbers!$tw$, $tw$[{"q": "An AI tool gives you an answer for homework. What should you do?", "options": ["Check it in a textbook or with a teacher", "Trust it completely", "Never read it"], "answer": 0}, {"q": "What is Scratch?", "options": ["A free coding platform that uses blocks", "A type of AI drone", "A video game console"], "answer": 0}, {"q": "How does AI predict the weather?", "options": ["It finds patterns in lots of weather data", "It guesses randomly", "It looks out of the window"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 8, $tw$Chapter 5: Ethical AI and staying safe$tw$, $tw$Using AI safely, fairly and kindly$tw$, $tw$## 🛡️ What are ethics in AI?

**Ethics** means knowing what is right and fair. Ethical AI means:

- Making sure AI **doesn't harm or trick** people
- Treating **everyone fairly**, no matter where they come from or what they look like

AI learns from data. If the data is unfair (for example, only photos of some kinds of people), the AI can be unfair too. That's called **bias**, and AI ethicists work hard to fix it.

![Three golden rules: ask a trusted adult, check your sources, be kind](https://tinkerwith.me/assets/courses/ai-workbook/stay-safe.svg)

## Tips for kids and parents

1. **Ask a trusted adult** before sharing personal information with AI or any online tool.
2. **Check your sources.** AI tools can give wrong answers. Compare with other sources.
3. **Respect others.** Never use AI to bully, make fake pictures of people, or spread rumours.

## Avoiding misinformation and protecting your data

- Always **verify facts** in a second place, or with a teacher or parent.
- **Keep private:** your full name, school, address, phone number, passwords and photos of yourself.
- Pictures and videos can be **made or changed by AI**. If something looks too strange to be true, it might be fake!

### ✏️ Activity: real or fake?

With a grown-up, look at 3 news headlines or pictures online. For each one, ask:

1. **Who** made this?
2. Can I find it in **another trusted place**?
3. Does anything look **strange** (extra fingers, odd shadows, blurry text)?

Write your verdict, **real** or **maybe fake**, in your AI Journal.$tw$, $tw$[{"q": "An AI chatbot asks for your home address. What should you do?", "options": ["Type it in", "Don't share it, and tell a trusted adult", "Share your school's name instead"], "answer": 1}, {"q": "What is bias in AI?", "options": ["When AI is unfair because it learned from unfair data", "A kind of computer chip", "When AI runs very fast"], "answer": 0}, {"q": "True or false: if an AI says something, it must be true.", "options": ["True", "False"], "answer": 1}, {"q": "Is it OK to use AI to make a funny fake picture of a classmate?", "options": ["Yes, it's just a joke", "No, it can hurt them, so be kind"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 9, $tw$Chapter 6: Hands-on activities$tw$, $tw$Puzzles, colour-by-algorithm and community projects$tw$, $tw$## 🧩 AI crossword

Print this page or copy the grid into your AI Journal, then fill it in!

![AI crossword grid with clues](https://tinkerwith.me/assets/courses/ai-workbook/crossword.svg)

## 🖍️ Colour-by-algorithm

Draw a simple picture with **6 sections** (like a house, a tree, the sun, the sky, grass and a door). Number the sections 1 to 6. Then follow these rules to colour it:

| Section | Clue | If TRUE colour… | If FALSE colour… |
| --- | --- | --- | --- |
| 1 | Machine learning is part of AI | 🟩 green | 🟥 red |
| 2 | AI is always right | 🟦 blue | 🟨 yellow |
| 3 | Data is information we give to AI | 🟧 orange | ⬛ grey |
| 4 | An algorithm is a set of steps | 🟨 yellow | 🟪 purple |
| 5 | It's OK to share passwords with a chatbot | 🟥 red | 🟩 green |
| 6 | Generative AI can make pictures | 🟦 blue | 🟫 brown |

You just followed an algorithm! **If this, then that** is how computers make decisions.

## 🌍 Community problem solving

Pick a problem in your community, like **waste and litter**, **saving water**, or **traffic**.

1. Describe the problem in 2 sentences.
2. Brainstorm: **how could AI help?** (A camera that sorts rubbish? An app that spots leaking pipes?)
3. Draw your invention and give it a name!
4. Share it with your family or class.

<details><summary>Crossword answers (no peeking!)</summary>

Across: 2. ETHICS · 4. ALGORITHM. Down: 1. KENYA · 3. AI

</details>$tw$, $tw$[{"q": "In colour-by-algorithm, 'AI is always right' is…", "options": ["TRUE", "FALSE"], "answer": 1}, {"q": "What kind of instruction do computers use to make decisions?", "options": ["If this, then that", "Maybe, maybe not", "Wait and see"], "answer": 0}, {"q": "Which country did M-Pesa start in?", "options": ["Nigeria", "Kenya", "Egypt"], "answer": 1}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 10, $tw$Famous AI inventors and innovators$tw$, $tw$AI inventors and innovators$tw$, $tw$## 🌟 People who shaped AI

### A brief history

- **Alan Turing (UK)** laid the foundations of modern computing and, in 1950, asked the famous question: *"Can machines think?"*
- **John McCarthy (USA)** came up with the name **"Artificial Intelligence"** in the 1950s.

### African innovators

- **Timnit Gebru (Ethiopia)** is famous for her work on **AI ethics and fairness**, and founded an AI research institute (DAIR).
- **The Masakhane community** is a group of researchers across Africa building AI for **African languages**.
- **Kenyan tech teams at iHub** in Nairobi have built tech solutions for healthcare, farming and money.
- **M-Pesa (Kenya, 2007)** is not AI, but this mobile money system changed how millions of people pay, and opened the door to tech ideas across Africa.

### Inspiring figures from around the world

- **Fei-Fei Li (China/USA)** built ImageNet, a giant collection of pictures that helped computers learn to **"see"** objects.
- **Demis Hassabis (UK)** co-founded DeepMind, which built **AlphaGo** and **AlphaFold**. AlphaFold won a Nobel Prize in 2024 for helping scientists understand proteins.

### ✏️ Activity: innovator trading card

Choose one innovator (or someone you know who uses tech to help others!) and make a trading card in your AI Journal:

- Name and country
- Draw their picture
- **Superpower:** what did they create or change?
- **Why it matters** to people like you$tw$, $tw$[{"q": "Who came up with the name 'Artificial Intelligence'?", "options": ["John McCarthy", "Alan Turing", "Fei-Fei Li"], "answer": 0}, {"q": "Timnit Gebru is known for work on…", "options": ["AI ethics and fairness", "Building football stadiums", "Mobile money"], "answer": 0}, {"q": "What does the Masakhane community work on?", "options": ["AI for African languages", "Self-driving cars", "Space rockets"], "answer": 0}]$tw$::jsonb);
end $$;

-- PART 3 of 3: lessons 11-14
do $$
declare cid uuid;
begin
  select id into cid from public.lms_courses where slug = 'ai-beginners-workbook';
  if cid is null then raise exception 'Run part 1 first.'; end if;
  delete from public.lms_lessons where course_id = cid and position between 11 and 14;
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 11, $tw$Final project: build your first AI chatbot$tw$, $tw$Project session 1: What is a chatbot?$tw$, $tw$## 💬 What is a chatbot?

A **chatbot** is a computer program that can **talk with people and answer questions**.

Chatbots are used in:

- Websites and help desks
- Customer support (like your bank or phone company)
- Learning apps
- Virtual assistants

**Your mission:** over the next three sessions, you'll learn how chatbots work, **build one in Scratch**, and **train an AI** to recognise faces.

⏱️ About 30 minutes · 👫 Best with a partner

![A user and a chatbot taking turns to talk](https://tinkerwith.me/assets/courses/ai-workbook/chatbot-roleplay.svg)

### ✏️ Activity: chatbot role play

1. Find a partner (a friend, brother, sister or grown-up).
2. One person is the **chatbot**, the other is the **user**.
3. The chatbot can only give answers it has "learned". Write 5 answers on a card first!

> **User:** Hello
> **Chatbot:** Hello! How can I help you?
> **User:** What is your name?
> **Chatbot:** I am a learning chatbot.

4. **Switch roles** after 2 minutes.

### Talk about it

- Was it easy to act like a chatbot?
- What happened when the user asked a question that wasn't on your card?
- What kind of questions could your chatbot answer?$tw$, $tw$[{"q": "What is a chatbot?", "options": ["A program that talks with people and answers questions", "A robot that cleans", "A type of keyboard"], "answer": 0}, {"q": "In the role play, what happened when the user asked something not on the card?", "options": ["The chatbot didn't know the answer", "The chatbot knew everything", "The computer turned off"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 12, $tw$Final project: build your first AI chatbot$tw$, $tw$Project session 2: Build a chatbot in Scratch$tw$, $tw$## 🐱 Build a simple chatbot in Scratch

**Goal:** create a chatbot that answers simple questions.

⏱️ About 40 minutes · 💻 Computer or tablet with a browser

### Step 1: open Scratch

Go to **[scratch.mit.edu](https://scratch.mit.edu/projects/editor/)** and start a new project. You don't need an account to try it, but ask a grown-up to help you sign up if you'd like to save your work online. You can also use **File → Save to your computer**.

### Step 2: find the chatbot blocks

You'll use these blocks:

- **when green flag clicked** (Events, yellow)
- **ask [question] and wait** (Sensing, blue)
- **if / then / else** (Control, orange)
- **say [response]** (Looks, purple)
- **join** and **=** (Operators, green)

### Step 3: build this code

![Scratch chatbot code blocks](https://tinkerwith.me/assets/courses/ai-workbook/scratch-chatbot.svg)

~~~
when green flag clicked
ask "Hello! What is your name?" and wait
say (join "Nice to meet you " answer)
ask "How are you today?" and wait
if answer = "good" then
    say "That is great!"
else
    say "I hope your day gets better!"
~~~

Click the **green flag** to test it. Type your answers in the box at the bottom of the stage.

### ✏️ Your task

Make your chatbot answer **3 questions**, for example:

- What is your name?
- What is your favourite colour?
- Do you like robots?

> 🌟 **Challenge:** add a question in Kiswahili! *"Habari yako?"* → if answer = "nzuri", say *"Safi sana!"*

### Why is this a chatbot?

Your chatbot **takes an input** (what you type), **follows rules** (if/then), and **responds automatically**. Real chatbots do the same, with much bigger sets of rules and AI that has learned from lots of conversations.$tw$, $tw$[{"q": "Which block makes the sprite ask a question?", "options": ["say", "ask and wait", "move 10 steps"], "answer": 1}, {"q": "Where does Scratch store what the user typed?", "options": ["In the 'answer' block", "In the green flag", "In the costume"], "answer": 0}, {"q": "What does 'if answer = good then' do?", "options": ["Checks the answer and chooses what to say", "Draws a picture", "Stops the program forever"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 13, $tw$Final project: build your first AI chatbot$tw$, $tw$Project session 3: Train an AI with Teachable Machine$tw$, $tw$## 📷 Train an AI with Teachable Machine

**Goal:** learn how AI can **recognise images or sounds** and trigger responses.

⏱️ About 40 minutes · 💻 Computer with a webcam

AI systems learn from **examples**. With Google's free **Teachable Machine**, you can train an AI to recognise:

- Images
- Sounds
- Body poses

![Teachable Machine: examples, train, test, chatbot reply](https://tinkerwith.me/assets/courses/ai-workbook/teachable-machine.svg)

> 🔒 Teachable Machine trains in your browser. Your webcam pictures stay on your computer unless you choose to save or share them.

### Activity: train a simple AI

**Step 1:** go to **[teachablemachine.withgoogle.com](https://teachablemachine.withgoogle.com/)**, click **Get started** and choose **Image Project → Standard image model**.

**Step 2:** create two classes:

- Class 1: **Happy face** 😀
- Class 2: **Sad face** 🙁

Click **Webcam** and **hold to record** about 30 pictures for each class. Move your head a little so the AI sees different angles.

**Step 3:** click **Train Model** and wait. Don't switch tabs while it trains!

**Step 4:** test it! Make a happy face, then a sad face, and watch the **Output** bars change.

### Connect it to your chatbot idea

If the AI detects:

- Happy face → chatbot says **"You look happy!"**
- Sad face → chatbot says **"Can I cheer you up?"**

That's how smart apps work: **AI recognises something**, then a **program decides what to do**.

> 🌟 **Challenge:** try a **Sound Project**: train it to tell the difference between a clap and a whistle!

### Experiment

- What happens if you only give **5 examples**? Is it still accurate?
- What if a friend tries it? Does it still work? Why or why not?$tw$, $tw$[{"q": "How does Teachable Machine learn?", "options": ["From the examples you show it", "It already knows everything", "From your passwords"], "answer": 0}, {"q": "What happens if you give the AI only a few examples?", "options": ["It may make more mistakes", "It becomes perfect", "Nothing changes"], "answer": 0}, {"q": "After the AI recognises a happy face, what decides what the chatbot says?", "options": ["A program with rules (if/then)", "The webcam", "The keyboard"], "answer": 0}]$tw$::jsonb);
  insert into public.lms_lessons (course_id, position, section, title, body, quiz) values (cid, 14, $tw$Final project: build your first AI chatbot$tw$, $tw$Final project and what's next$tw$, $tw$## 🏆 Your final project

Create a **fun chatbot** in Scratch that:

- **Greets** the user
- **Asks** at least 3 questions
- **Gives responses** using if/then/else

### Ideas

- 🤖 Robot helper
- 🦁 Animal chatbot (it pretends to be a lion at the Maasai Mara!)
- 🏫 School helper bot
- 📚 Homework assistant bot

Show your chatbot to your family. Can they find a question it doesn't understand?

## 🤔 Reflection questions

Answer these in your AI Journal:

1. What did your chatbot say?
2. What was the hardest part?
3. How could AI chatbots **help people** in your community?
4. Look back at the first page of your journal: can you now answer the question you had about AI?

## 🔑 Key learning

You learned that:

- AI **learns from data** and examples
- Programs can **understand inputs** and **respond automatically**
- Chatbots are built with **logic and data**
- AI is a powerful tool, so use it to **solve real problems** and stay **safe, fair and kind**

## 🚀 Keep exploring AI

- Join a local **coding club or robotics team**
- Try more beginner AI courses on **Tinkerwith**
- Build small AI projects with your classmates

### Resources

- **[Scratch](https://scratch.mit.edu/)**: beginner-friendly coding
- **[Teachable Machine](https://teachablemachine.withgoogle.com/)**: make simple AI models with images or sounds
- **[Code.org AI lessons](https://code.org/ai)**: free lessons about how AI works
- ***Hello Ruby: Adventures in Coding*** by Linda Liukas: a kid-friendly book about coding
- **TED-Ed** videos on YouTube about AI and robotics (watch with a grown-up)

### 🎉 Congratulations!

This workbook aims to inspire you to see yourself as a **creator** and **innovator** in AI. Complete this lesson to earn your **Tinkerwith certificate**!$tw$, $tw$[{"q": "What three things should your final chatbot do?", "options": ["Greet, ask questions and give responses", "Sing, dance and sleep", "Nothing, it just sits there"], "answer": 0}, {"q": "What does AI learn from?", "options": ["Data and examples", "Magic", "Nothing"], "answer": 0}]$tw$::jsonb);
end $$;
