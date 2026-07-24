# TinkerWithMe — authored AI lesson content

Source markdown for import_lessons.py. Each lesson becomes project_content/<id>.json
(zero AI tokens — this is your own authored copy). Format the importer reads:

  ## Lesson: <title>
  project: <catalogue id>       (metadata is pulled from courses.json by this id)
  **<Label>**  … section text …
  **Quiz**  Q: … then "- option" lines, marking the answer with [correct]

Add or edit lessons here, then run:  python import_lessons.py content_source/ai_lessons.md


## Lesson: How AI systems work
project: a10

**What you'll learn**
Every AI system has three parts: an input, a process in the middle, and an output.

**Key idea**
AI does not work on its own — a person designs what goes in, what happens, and what comes out.

**Activity**
Draw the pipeline on the board: INPUT → AI SYSTEM → OUTPUT. Work an example together — Input: your homework dates; Process: the app checks the calendar; Output: a reminder pops up. Then have each group pick three everyday AI tools (a photo filter, a voice assistant, a video recommendation) and label the input, the process, and the output for each.

**Remember**
If you can name the input and the output, you understand what an AI system is doing.

**Quiz**
Q: What comes first in an AI system?
- Output
- Input [correct]
- Result


## Lesson: Good Data, Bad Data
project: a11

**What you'll learn**
AI learns from data, and the data has to be fair and complete for the AI to be any good.

**Key idea**
Bad data creates bad decisions — an AI can only be as good as what it learns from.

**Activity**
Run a quick class survey (e.g. favourite fruit) and record the results. Then interrogate the data together: Did everyone get to answer? Was anyone left out? Would the result change if you only asked half the class? Discuss how a missing or unfair sample would teach an AI the wrong thing.

**Remember**
Fair, complete data in — trustworthy decisions out. Gaps and bias in the data become gaps and bias in the AI.

**Quiz**
Q: AI learns best from data that is:
- Random
- Fair and complete [correct]
- Small


## Lesson: Ethical AI design
project: a12

**What you'll learn**
Ethics guide responsible innovation — deciding not just what an AI *can* do, but what it *should* do.

**Key idea**
Not everything that is possible to build should be built. Fairness, privacy and safety come first.

**Reflection**
As a group, agree on the values that should guide an AI you would be proud to build. Then take a real product idea (a face-scanning school gate, a homework-grading bot) and pressure-test it against those values: who could it treat unfairly? what data does it collect? how would someone appeal a wrong decision?

**Remember**
Ethical AI is fair, transparent, and something you can explain and stand behind.

**Quiz**
Q: Ethical AI should be:
- Secret
- Fair and transparent [correct]


## Lesson: Explain AI to others
project: a13

**What you'll learn**
Leaders can explain technology clearly — understanding grows when you can teach it to someone else.

**Key idea**
If you can explain AI simply, you really understand it.

**Activity**
Each learner prepares a 3-sentence explanation of AI for a specific audience — a parent, a younger sibling, a head teacher. Practise in pairs, then a few present to the group. The audience scores each on: Was it clear? No jargon? Could you repeat it back? Iterate once and present again.

**Remember**
A good AI leader makes things clearer for others, not more confusing.

**Quiz**
Q: A good AI leader should:
- Confuse others
- Explain clearly [correct]
