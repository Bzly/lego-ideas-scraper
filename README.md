# LEGO Ideas blog post scraper/alerter

Builds a local database of [LEGO ideas blog](https://ideas.lego.com/blogs/a4ae09b6-0d4c-4307-9da8-3ee9f3d368d6) posts on first run, and on subsequent runs sends the user a toast notification for new posts that match set criterea.

I really dislike having to sift through posts to find the review qualification/results ones - LEGO, please [add tag/type filtering](https://legoideas.uservoice.com/forums/166718-general/suggestions/46433518-add-filters-to-the-lego-ideas-blog) to the Ideas blog!

## Installation

Choose whether you'd like to run this with PowerShell Desktop (latest version 5.1), which comes pre-installed with Windows, or [PowerShell Core](https://github.com/PowerShell/PowerShell) (v7.1 or higher recommended).

PowerShell 5.1 is easiest as it is likely already on your system, but does have a functionality drawback: you cannot click anywhere on the notification to 'activate' it and open the blog post; rather you must click specifically on the button underneath. Versions 7.1+ do not have [this issue](https://github.com/Windos/BurntToast/blob/3f0460be1c59dd430132360139372f31d951c45d/BurntToast/BurntToast.psm1#L45).

### PowerShell Gallery

From a PowerShell (v5.1+) prompt, run:
```
Install-Module -Name LegoIdeas
```

Enter `Y` or `A` when prompted to trust the repository.

This will install the LegoIdeas module and its one dependency, [BurntToast](https://github.com/Windos/BurntToast) (for toast notifications).

### Manual

1. Download the `LegoIdeas` folder from this repository
2. Place in your `$PSProfile\Modules` folder. PS will load correctly formatted modules from here automatically on launch.
    * For 5.1/Desktop: `C:\Users\<username>\Documents\WindowsPowerShell\Modules`
    * For 6+/Core: `C:\Users\<username>\Documents\PowerShell\Modules`
3. Install [BurntToast](https://github.com/Windos/BurntToast) as well

## Setup

1. Open your favourite PowerShell (or run `refreshenv` if you haven't closed the one from earlier installation)
2. Run `Get-NewLegoIdeasPosts` to build your initial database of posts (`posts.json`) and your user config (`config.json`). These will be in `C:\Users\<username>\AppData\Local\Legoideas\`. The first run will take ~a minute to get through all the pages. 
3. Subsequently run `Get-NewLegoIdeasPosts` again at any point, to add new posts to the local database and be alerted of any matching preferences set in your `config.json`. 
    * It is recommended to schedule this with e.g. Task Scheduler. You can import `CheckIdeasTask.xml` from this repository, or create your own. Daily or weekly checks recommended.

## Configuration

The default config looks like this:
``` json
{
    "blacklist": [
        "10K Club Interview"
    ],
    "whitelist": [
        "review",
        "introducing",
        "available now"
    ]
}
```

Posts with blacklist words in the title will not trigger notifications unless they also contain a whitelist phrase. It is set up by default to ignore the interviews with creators who reach the 10K milestone. 

If you make changes, don't forget your commas. 

## Pitfalls

This approach could break if LEGO decide to update the structure of the Ideas blog - such is the nature of web scraping. We use Regex matches in three places:

1. To retrieve the JSON post data
2. To extract the published time from the output of 1
3. To get the number of pages in the blog from the pagination element

A change to the logic in 1 or 2 will break this module; 3 will merely result in the progress bar for initial scrape being unhelpful.