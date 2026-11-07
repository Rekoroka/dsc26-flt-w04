# AI usage: dsc26-flt-w04

AI tools are allowed in this task. Fill in every section in your own words. This file is read by your Track Mentor, not by the grader.

## 1. Tools I used

- **Claude**: step-by-step explanations of the task and the starter code, reviewing my code, and helping me read test failures. I wrote and applied the changes in the stop-list screen myself. For the outbox, Claude wrote the code and I read through it with the explanations.
- **ChatGPT**: an initial explanation of the task, which I then asked Claude to review.
- **flutter test**: running the public tests after every change.
- **Chrome DevTools (Device Toolbar) and my phone**: testing widths around 600, text at 200%, and right-to-left layout by hand.

## 2. My best prompts

1. I asked for an explanation of each file before changing anything: what it does, what already exists, what the task still needs, and which widgets I would be reviewing. This helped me understand the starter code instead of editing blindly.
2. I told the assistant not to fix my code for me, but to explain the problem so I could fix it myself. I also pasted the full `flutter test` output and asked what it meant. For example, the rectangle in the failed accessibility test showed that the call button was already 48x48, so the real problem was the missing label.

## 3. One bug I found in AI-generated outbox or layout code, and how

The suggested plan for selecting the first stop used `initState` to store the selected stop. The problem is that `initState` runs only once. If the screen is rebuilt with a new list of stops (the hidden tests pump the widget with different data), Flutter reuses the same State object and the old selected stop stays on screen. The same code also had `super.initState;` without parentheses, which compiles but never calls the method.

I noticed it while reviewing my code with Claude, not from a failing test. To fix it, I stored only the id of the selected stop and compute the selected stop from the current list each time, falling back to the first stop. That removed the need for `initState`.

## 4. Why 409 is a success, and why corrections are appended after an attempt

The main goal of the outbox is that the server has the outcome. A 409 means the server already has it, so nothing failed and it is safe to delete the local copy. This can happen when the server saved the request but the answer never reached the phone, so the app sent it again.

If an entry was already sent and the courier corrects it, changing the same entry would send different data with the same id, which can conflict with what the server has. The server would answer 409, we would treat it as a success and delete the entry, and the correction would be lost. So the correction is added as a new entry with a new id.