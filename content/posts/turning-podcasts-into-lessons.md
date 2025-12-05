+++
title = "Can cheap AI models turn a podcast into a lesson?"
date = "2025-12-05"
categories = ["Education", "AI"]
tags = ["experiments"]
type = "posts"
draft = false
+++

At work, I build AI agents(trigger warning this is about LLMs) that are designed to help teachers avoid as much day to day drudgery as possible. We provide a system that, counterintuitively, is geared towards reducing the amount of time a teacher needs to spend in the app spelunking around. Need the latest assessment grades for Mrs Doe's 3rd period? Just ask the Ai, it'll go off and grab that information for you while you pour another cup of coffee.
We use top of the line models from Anthropic to be as accurate, un-biased, error free as possible to achieve this. These models require API keys and 5-figures in engineering time just to put the guardrails in place to allow a Teacher/Administrator to use them in relative safety.

This isn't that.

At the other end of the market, where the enthusiasts play, are small unsafe models that run on laptops or specialty desktops. Instead of ChatGpt, Claude or Gemini, it's Llamas, Qwen, Gemma and Mistral (among others). These range from 1GB sized tiny models good for basic grammar checking and autocomplete up through 1TB monsters that can compete directly with commercial offerings like openai's gpt-4+. The ecosystem is truly diverse although you might get some side-eye from co-workers if you bring up the website in polite company https://huggingface.co/models . 

What's interesting about these is how low the barrier to entry truly is. If you happen to have a recently built gaming PC or a recent M-series Mac, with some tinkering you can probably run these small LLMs at fairly usable speeds. I recently bought a machine from Framework, the [Framework Desktop](https://frame.work/desktop), that houses a special chip with enough memory to run even larger models with decent responsiveness.

Using this machine I can run experiments without shipping data to the big model providers or, worrying about the cost of running experiments on bulk data, even if the quality and safety isn't the same as what you get with model providers.

I decided to see if my current favorite small+local model [Qwen3 - 30b](https://huggingface.co/Qwen/Qwen3-VL-30B-A3B-Thinking-FP8), could do a decent job with what felt like a pretty hard task: Taking a podcast, video, etc and turning it into a lesson plan someone might actually want to use. So, I decided to try it out on one of my favorites [The Weekly Show With Jon Stewart](https://podcasts.apple.com/us/podcast/american-heritage-vs-american-history/id1583132133?i=1000739647094). In this episode they talk quite a bit about the American founding, what it means to be an American, etc etc. This felt like great fodder for a high school civics lesson.

So I transcribed the episode, fed that to Qwen3 and asked for a '9th grade civics lesson based on the transcript'. What follows is the result, good bad or terrible I'll let you judge but I think it's damn interesting from something that sits on my desk.

--- 

# Lesson Plan: "What Makes an American?" - Understanding America's Proposition Nation

## Grade Level
9th Grade

## Duration
2 class periods (90 minutes each)

## Learning Objectives
- Analyze America's founding documents to understand the concept of America as a "proposition nation"
- Examine the tension between America's ideals and historical realities regarding slavery and exclusion
- Explore how the concept of "heritage Americans" has evolved historically
- Understand how immigration policies reflect changing ideas about who is "American"
- Connect historical concepts to contemporary debates about American identity

## Materials Needed
- Podcast transcript (provided in the prompt)
- Whiteboard or projector
- Student handouts with key quotes from the podcast
- Primary source documents (Declaration of Independence, Constitution excerpts)
- Timeline activity worksheet
- Reflection journal prompts

## Lesson Plan

### Period 1: The Founding Ideals and the American Proposition

**1. Warm-up (10 minutes)**
- Ask students: "What does it mean to be an American? What qualities or experiences make someone 'American'?"
- Record responses on whiteboard
- Briefly discuss how students' answers reflect different ideas about American identity

**2. Introduction to the Concept (15 minutes)**
- Explain the concept of America as a "proposition nation" (founded on ideals rather than shared ethnicity or geography)
- Highlight key quotes from the podcast:
  - "We came conceived in this idea of liberty and dedicated to a proposition."
  - "In America, you can become an American in 20 minutes. You read the Declaration, you read the Constitution, you sign on it. You understand it. You're in."
- Show visual aids of the Declaration of Independence and Constitution

**3. Primary Source Analysis (25 minutes)**
- Provide excerpts from the Declaration of Independence and Constitution
- Students work in small groups to identify:
  - What ideals are expressed?
  - How do these ideals create a "proposition"?
  - Who was included in these ideals? Who was excluded?
- Discuss as a class

**4. Historical Context (25 minutes)**
- Review key historical context:
  - The founding fathers' understanding of "citizen" versus "national"
  - The tension between ideals and reality (slavery, exclusion of women)
  - How the founders themselves had different understandings of who belonged in the American experiment
- Highlight relevant podcast content:
  - "We are in a wilderness without a path"
  - "John Adams says, we didn't know what we were doing"
  - "They thought about things. It was improv"

**5. Reflection (10 minutes)**
- Quick write: "Based on what we've learned, how would you respond to someone who says 'I'm a heritage American because my family has been here for 300 years?'"

### Period 2: Evolution of American Identity and Contemporary Debates

**1. Review and Transition (10 minutes)**
- Review key points from Period 1
- Transition to how the concept of American identity has evolved over time

**2. Historical Development Activity (25 minutes)**
- Create a timeline on the board with key moments in American identity development:
  - 1776 (Declaration of Independence)
  - 1860s (Civil War era)
  - 1924 (Immigration Act)
  - 1965 (Immigration Act)
  - Present day
- Students work in groups to analyze how each period reflected different understandings of "American identity"
- Discuss the podcast's explanation of the 1924 immigration act and the role of anxiety in nativist movements

**3. Case Study: "Heritage Americans" (25 minutes)**
- Introduce the concept of "heritage Americans" as discussed in the podcast
- Students analyze:
  - Why the term is often used in contemporary political debates
  - Historical precedents for this kind of thinking
  - How the concept relates to the idea of America as a proposition nation
- Use the podcast quote: "The more benign definition of it is, well, we're seeing it through a lens of those that have been here longer, whereas the more maybe loaded one is, yeah, it's for white people."

**4. Contemporary Connections (20 minutes)**
- Discuss current debates about immigration and citizenship
- Analyze how the founding ideals relate to contemporary issues
- Students consider:
  - How can America's proposition nation ideals guide contemporary debates?
  - What tensions exist between the ideals and current realities?
- Use podcast content about how the founders didn't define American identity narrowly

**5. Final Reflection and Application (10 minutes)**
- Students write a short response:
  - "In what ways does the concept of America as a proposition nation help us understand contemporary debates about who belongs in America?"
  - "How might we apply the ideals of the founding to create a more inclusive vision for America's future?"

## Assessment

### Formative Assessment
- Class participation and group work
- Completed analysis worksheets
- Reflection journal prompts

### Summative Assessment (Optional)
- Short essay comparing the founding ideals with contemporary American identity debates
- Group presentation analyzing how a specific historical event affected American identity

## Differentiation Strategies

- **For struggling students:** Provide guided questions for primary source analysis
- **For advanced students:** Assign additional research on specific immigration acts or historical figures
- **For visual learners:** Create graphic organizers for the timeline activity
- **For kinesthetic learners:** Include role-play scenarios where students argue for different interpretations of "American identity"

## Extension Activities

1. **Research Project:** Choose a historical figure from the founding era and analyze how their views on citizenship and American identity reflect or challenge the proposition nation concept

2. **Debate:** Organize a debate on whether America should continue to be defined as a proposition nation or move toward a more biological understanding of national identity

3. **Creative Writing:** Students write a short story from the perspective of an immigrant arriving in America in different historical periods (1700s, 1800s, 1900s, today), exploring how they would view what it means to be "American"

## Key Teaching Notes

1. **Focus on critical thinking:** The goal is not to present a single "correct" interpretation but to help students understand how historical concepts develop over time.

2. **Emphasize complexity:** The podcast makes clear that there was tension between ideals and reality from the beginning of the nation.

3. **Connect to present day:** Use the podcast to make clear how these historical ideas continue to shape contemporary debates.

4. **Address potential sensitivities:** The discussion of race, immigration, and national identity can be emotionally charged. Create a respectful classroom environment with clear ground rules for discussion.

5. **Highlight the value of historical understanding:** As the podcast suggests, understanding the complexities of history helps us navigate current debates with greater nuance.

This lesson plan draws from the rich historical insights provided in the podcast while adapting the content for a 9th grade audience. It encourages students to think critically about fundamental questions of American identity while connecting historical concepts to contemporary issues they face in their own lives.

