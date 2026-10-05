-- Tidy the course cards of the free starter courses (summary, description, ages).
-- Run in Supabase -> SQL Editor. Safe to run more than once.
update public.lms_courses set
  summary = 'A free 30–45 minute starter: spot AI in everyday life, see how simple chatbots work, and think about using AI fairly.',
  description = $tw$A short, free introduction to artificial intelligence for kids aged 10 and up, and the parents and teachers who learn with them.

**What you'll do**

- Spot the AI in apps and devices you already use
- Try an activity to tell AI from non-AI
- See how a simple chatbot works
- Read a short story about AI and fairness, and reflect on it

**How long:** about 30–45 minutes, at your own pace. Ends with a certificate.$tw$,
  age_range = '10+'
where slug = 'what-is-ai';

update public.lms_courses set
  summary = 'A free hands-on starter: wire up a set of Arduino traffic lights and learn circuits, components and your first code.',
  description = $tw$A free, hands-on introduction to robotics and coding. You'll build a working set of **traffic lights with an Arduino**, step by step.

**What you'll learn**

- The parts: breadboard, Arduino, LEDs, jumper wires and resistors
- How to connect a simple circuit safely
- Your first Arduino code to make the lights change

**You'll need** an Arduino starter kit (an Arduino, a breadboard, red, yellow and green LEDs, jumper wires and a resistor), or the Tinkerwith Maker Kit, which you can order through Anne.

Ends with a certificate, and a pointer to the next builds.$tw$,
  age_range = '8–14'
where slug = 'robotics-101';
