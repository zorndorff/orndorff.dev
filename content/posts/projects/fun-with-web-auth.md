+++
title = "So, how do you use the Web Authentication API anyway?"
date = "2022-10-25"
categories = ["projects", "auth", "NestJs"]
type = "posts"
draft = true
+++

The web is a fantastic, decentralized platform with wonderful features that can be used without going through big cloud gatekeepers. 
Unfortunately, we tend to forget this and reach for commercial, cloud offerings when there are open standards that can achieve the same or better results. 

Recently, I've been implementing yet another authentication system and started wondering what the native `Web Authentication API` built into 99% of browsers offered.
What does it get you and what does it take to use Web Authentication in a real world application? 

Lets find out!

The, always wonderful, mdn documentation does a pretty good job of explaining the security and privacy benefits [Web Authentication API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API#web_authentication_concepts_and_usage), so I won't bother rephrasing them here. 

## Covered in this post.

- How to register a user with the Web Authentication Api.
- How to authenticate a user with the Web Authentication Api.

## Setup

I'll start the simplest way I know how, using [express-generator-typescript](https://www.npmjs.com/package/express-generator-typescript). Stand on the shoulders of giants, and all that.

```shell
> npx express-generator-typescript fun-with-web-auth
```

This gets a nice, usable express project with the heavy lifting done for us. I'm lazy.

If you're so inclined, the repo for this article, thought experiment, whatever it is, is available here:
[zorndorff/fun-with-web-authentication](https://github.com/zorndorff/fun-with-web-authentication)

## Registering a user

There are 6(seems a lot) steps involved in registering a user using this technique.

This process is outlined here: [Registration](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API#registration) and can be boiled down to:

1. A request is made to your server to begin registration, the server responds with a challenge. This includes a challenge key and user information that the `Authenticator`(the hardware token or application storing the end-user's credentials) is verifying for us.
1. Your JavaScript code passes the challenge to an `Authenticator` with `authenticatorMakeCredential`. This will return a signed `Credential` that can be used to `Authenticate` the user later.
1. The `Authenticator` generates a public:private key pair and `Attestation`, this is the user data that the `Authenticator` is vouching for.
1. The new `Credential` is returned to the browser, this includes a GUID that can be used to differentiate between credentials.
1. The `Credential` and any supporting data is then sent to your server where the new Credential is validated. These checks include verification that the origin, signature and certificates are all as expected.

What this looks like in our client code.

A simple, non-exhaustive implementation looks something like this:






## Logging in a user

