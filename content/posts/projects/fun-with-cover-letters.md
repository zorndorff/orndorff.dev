+++
title = "AI written cover letters fun and profit."
date = "2022-12-04"
categories = ["projects", "ai", "openai", "gpt-3", "gigs"]
tags = ["gpt-3", "ai"]
type = "posts"
draft = false
+++

In today's newly competitive tech jobs market, it's more important than ever to have a well-written cover letter when applying for a job. It's your opportunity to make a great first impression and set yourself apart from other candidates. But writing a unique and compelling cover letter for each job you apply to can be time-consuming and daunting. That's where GPT-3 comes in.

GPT-3, or Generative Pretrained Transformer 3, is a state-of-the-art language model developed by OpenAI. It has been trained on a massive amount of text data, allowing it to generate human-like text on a wide range of topics. In this post, we'll show you how to use GPT-3 to generate custom cover letters for job applications.

## Summarizing the Candidate's Resume

First, let's start by summarizing the candidate's resume using GPT-3. This will allow us to extract important information about the candidate's experience and skills.

To do this, we'll use the openai package, which provides an easy-to-use interface for interacting with GPT-3. First, we'll need to install the package:

```
npm install openai
```

Next, let's create a function that takes in the candidate's resume as input and returns a summary of their experience and skills:

```
const openai = require('openai')

async function summarizeResume(resume) {
  openai.apiKey = "<your-openai-api-key>"
  
  const summary = await openai.completions.create({
    prompt: resume,
    max_tokens: 256,
    temperature: 0.5,
    model: "text-davinci-003"
  })

  return summary.choices[0].text
}
```

The `summarizeResume` function uses the completions endpoint of the OpenAI API to generate a summary of the resume. We pass in the resume text as the prompt, and specify the maximum number of tokens (i.e. words) to generate using the max_tokens parameter. We also set the temperature to 0.5, which will make the generated text more diverse and less repetitive. Finally, we use the text-davinci-003 model, which is well-suited for generating human-like text.

## Summarizing the Job Description

Next, let's create a similar function to summarize the job description. This will allow us to extract important information about the role and the requirements for the position.

```
async function summarizeJobDescription(description) {
  openai.apiKey = "<your-openai-api-key>"
  
  const summary = await openai.completions.create({
    prompt: description,
    max_tokens: 256,
    temperature: 0.5,
    model: "text-davinci-003"
  })

  return summary.choices[0].text
}
```

## Generating the Cover Letter

Now that we have summarized the candidate's resume and the job description, we can use GPT-3 to generate a custom cover letter. To do this, we'll create a function that takes in the summaries of the resume and job description, and uses them to generate a cover letter.

```
async function createCoverLetter(jobDescription, resumeSummary) {
  openai.apiKey = "<your-openai-api-key>"
  
  const coverResponse = await openai.completions.create({
    prompt: `${jobDescription} - ${resumeSummary} - Write a cover letter.`,
    max_tokens: 256,
    temperature: 0.5,
    model: "text-davinci-003"
  })

  return coverResponse.choices[0].text
}
```

While it's not perfect, this approach can result in impressive output with relatively little effort.

Here's an example where everyone's favorite billionaire applies for a job at Twitter.

> Dear Hiring Manager, 

> I am writing to express my interest in the position you have posted. As an experienced entrepreneur, engineer and physicist, I believe I have the necessary experience and qualifications to be a successful candidate for this role. 

> My expertise lies in technology development and business development, as well as project management and team leadership. I have 7+ years of experience developing web applications and working with Data Structures & Algorithms. Additionally, I have extensive experience working with universal React web applications and Progressive Web Apps, as well as data-informed product development such as analytics and A/B testing. My design & architecture skills are also strong, enabling me to develop software engineering best practices including agile development, unit testing & code reviews.

> My education background includes a Bachelor of Science in Physics & Economics from the University of Pennsylvania (1995) and a Master of Science in Energy Physics from Stanford University (1999). 

> In my career thus far, I have established companies such as SpaceX (2002-present), Tesla (2008-present), The Boring Company (2016-present), OpenAI (2015-present) and Neuralink (2016-present).

> Overall my combination of technical skills, industry knowledge & entrepreneurship make me an ideal candidate for this position. Furthermore, my passion for problem solving ensures that I would be able to take on any challenges presented by the role with enthusiasm.

> I am confident that my candidacy stands out among other applicants due to my extensive industry knowledge combined with the strategic planning & execution capabilities that come from running multiple companies over the years. Thank you for your time considering me for this role; if given the opportunity I will bring enthusiasm & dedication beyond what is expected from me into work every day at Twitter! 

> Sincerely yours, 
> Elon Musk


It's not perfect but, with a little editing from a human, it gets the job done!
