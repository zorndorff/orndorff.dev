+++
title = "So, how do you use the Web Authentication API anyway?"
date = "2022-10-25"
categories = ["projects", "auth", "NestJs"]
type = "posts"
draft = true
+++

It's easy to forget but, the web is a fantastic, decentralized platform with wonderful features that can be used without going through big cloud gatekeepers. Unfortunately, we tend to forget this and reach for commercial, cloud offerings when there are open standards that can achieve the same or better results. Lately, I've been implementing yet another authentication system and started wondering what web+browser-native apis could be available for authentication purposes. Could the `Web Authentication API` built into 99% of browsers work for basic authentication? What does it take to use Web Authentication in a real world application? Lets find out!
The, always wonderful, mdn documentation does a pretty good job of explaining the WAAPI(?)'s security and privacy benefits [Web Authentication API at Mdn](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API#web_authentication_concepts_and_usage), so I won't bother rephrasing them here. 

### Covered in this post.

- A basic user registration flow using Web Authentication Api
- Authentication and authorization using Web Authentication Api

## Setup

I'll start the simplest way I know how, using [express-generator-typescript](https://www.npmjs.com/package/express-generator-typescript). Stand on the shoulders of giants, and all that.

```shell
> npx express-generator-typescript fun-with-web-auth
```

This gets a nice, usable express project with the heavy lifting done for us. I'm lazy.

If you're so inclined, the repo for this article, thought experiment, whatever it is, is available here:
[zorndorff/fun-with-web-authentication](https://github.com/zorndorff/fun-with-web-authentication)


## Registering a user

There are 6(seems a lot) steps involved in creating a `Credential` that can later be used for authentication against our fun-with-web-auth service.
This process is outlined here: [Registration](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API#registration) and can be boiled down to:

1. A request is made to your server to begin registration, the server responds with a challenge. This includes a challenge key and user information that the `Authenticator` is verifying for us.
1. 


## Logging in a user

