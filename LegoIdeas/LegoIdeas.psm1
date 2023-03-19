# This needs to be saved with UTF-8 BOM encoding, else PS 5.1 throws a tizzy over the calendar emoji 🙄

$configDir =    "$env:LOCALAPPDATA\LegoIdeas\"
$configFile =   Join-Path -Path $configDir -ChildPath "config.json"
$postsFile =    Join-Path -Path $configDir -ChildPath "posts.json"
$site =         "https://ideas.lego.com"
$blogId =       "a4ae09b6-0d4c-4307-9da8-3ee9f3d368d6"
$defaults = @{
    whitelist = @(
        "review",                   # Review qualification/results
        "introducing",              # Product announcements
        "available now"             # Product in LEGO stores
    )
    blacklist = @(
        "10K Club Interview"        # Contributor Interviews
    )
}

function Get-NewLegoIdeasPosts {
    $cfg = getConfig
    $localPosts = getLocalPosts
    $latestPost = $localPosts[-1].uuid

    while ($latestPost -notin $results.uuid) {
        [Array]$results += parsePosts(queryLegoIdeasByPage($i++))
    }

    Write-Host "Latest local post was found on page $i"
    $newPosts = $results | ? {$_.uuid -notin $localPosts.uuid}
    Write-Host "$($newPosts.Length) new post(s) found"

    if ($newPosts.Length -gt 0) {
        $localPosts += $newPosts
        $localPosts | ConvertTo-Json | Out-File $postsFile

        $filteredPosts = $newPosts | filterPosts
        Write-Host "$($filteredPosts.Length) post(s) passed filter rules"
        notify($filteredPosts)
    }
    return $null
}

# Retrieves user config, if doesn't exist writes one with default values
function getConfig {
    if (!(Test-Path -Path $configFile)) {
        New-Item -Path $configFile -ItemType File -Force | Out-Null
        $defaults | ConvertTo-Json | Out-File -FilePath $configFile
    }
    return Get-Content -Path "$configFile" | ConvertFrom-Json
}

# Retrieves local posts, if none stored triggers initial full-scrape
function getLocalPosts {
    if (!(Test-Path -Path $postsFile)) {
        Write-Host "No local posts found, retrieving..."
        $p = parsePosts(queryLegoIdeas)
        $p | ConvertTo-Json | Out-File $postsFile
        return $p
    } else {
        $p = Get-Content -Path $postsFile | ConvertFrom-Json
        Write-Host "$($p.Length) posts found locally"
        return $p
    }
}

# Initial scrape of all posts, with progress bar and duplicate protection
function queryLegoIdeas {
    $pg = 1
    while ($pg -ge 1) {
        if ($pg -eq 1) {Write-Progress -Activity "Getting all LEGO Ideas posts" -Status "Page $pg/?" -PercentComplete 1}
        $p = queryLegoIdeasByPage -Page $pg -Extra $true
        if ($p.Posts.Length -gt 0) {
            [Array]$posts += $p.Posts
            Write-Progress -Activity "Getting all LEGO Ideas posts" -Status "Page $pg/$($p.MaxPages)" -PercentComplete (100*$pg/($p.MaxPages))
            $pg++
        } else {
            $pg = -99
            Write-Progress -Activity "Getting all LEGO Ideas posts" -Status "Done!" -Completed
        }
    }
    Write-Host "$($posts.Length) posts retrieved"
    return $posts | Sort-Object -Property uuid -Unique      # Just in case there's a post whilst the loop is running (and pages shift)
}

# Gets a single page of blog posts
function queryLegoIdeasByPage {
    param (
        [int]$Page = 1,
        [switch]$Extra = $False
    )
    $url = "$site/blogs/$blogId"
    $q =    "blog_posts_page"
    $body = @{$q = $Page}
    $Resp = Invoke-RestMethod -Uri $url -Body $body
    # PowerShell can't parse HTML, but luckily the LEGO Ideas site gives us the post data as JSON
    # Just one wafer thin regex match...
    $Matches = ([regex]::Matches(
        ([System.Web.HttpUtility]::HtmlDecode($Resp)), 
        "(?<=:config=')(.*)(?='>)")
    ).Value
    $p = getBlogPosts($Matches)

    # Add some extra information to returned data, so the initial scrape
    # can display a progress bar
    if ($Extra) {
        $pagination = ([regex]::Matches(
            ([System.Web.HttpUtility]::HtmlDecode($Resp)), 
            "(?<=blog_posts_page=)([0-9]+)(?=.+pagination--last)")
        )
        if ($pagination.Success) {[int]$MaxPages = $pagination.Value} else {$MaxPages = $Page}
        return @{
            Posts = $p
            MaxPages = $MaxPages
        }
    } else {
        return $p
    }
}

# Filters out matches from our regex that are not blog posts
# (Lego return json data in a few places, in the same way)
function getBlogPosts($Matches) {
    ForEach ($p in $Matches) {
        $j = $p | ConvertFrom-Json
        if (($j | Get-Member -Type NoteProperty).Name -contains "entity") {
            [Array]$out += $j.entity
        }
    }
    return $out
}

# Get the useful bits of data out
function parsePosts($Posts) {
    ForEach ($p in $Posts) {
        $dt = ([regex]::Matches(
            ([System.Web.HttpUtility]::HtmlDecode($p.published_at)),
            "(?<=datetime=`")(.+?Z)?(?=`")")
        ).Value
        [Array]$out += @{
            uuid = $p.uuid
            published_at = $dt
            title = $p.title
            img_url = $p.image_url_square
            preview = $p.truncated_content
        }
    }
    return $out | Sort-Object -Property {Get-Date ($_.published_at)}
}

# Pipe an array of parsed posts to this to filter by user's preferences
filter filterPosts {
    $inBlacklist = $false
    $inWhitelist = $false
    ForEach ($bw in $cfg.blacklist) {
        if ($_.title -like "*$bw*") { $inBlacklist = $true; break }
    }
    ForEach ($w in $cfg.whitelist) {
        if ($_.title -like "*$w*") { $inWhitelist = $true; break }
    }
    if ($inWhitelist -or !$inBlacklist) { $_ }
}

# Send notifications to the user
function notify {
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]$Posts
    )
    ForEach ($p in $Posts) {
        $notifHeader = New-BTHeader -Title "New LEGO Ideas blog post!"
        $notifTitle = "📆: $((Get-Date ($p.published_at)).toString("ddd dd MMM"))"
        $url = "$site/blogs/$blogId/post/$($p.uuid)"
        $butt = New-BTButton -Content "Open in browser" -Arguments $url
        # Variables don't expand in ScriptBlocks with { ... $url } method
        # Actions do not fire when shell has exited before triggered
        # https://github.com/Windos/BurntToast/discussions/145
        $params = @{
            AppLogo =           $p.img_url
            Text =              $notifTitle,$p.title
            Header =            $notifHeader
            Button =            $butt
            UniqueIdentifier =  ($p.uuid)
        }
        # https://github.com/Windos/BurntToast/blob/3f0460be1c59dd430132360139372f31d951c45d/BurntToast/BurntToast.psm1#L45
        if ($PSVersionTable.PSVersion -gt [Version]'7.1.0') {
            $params += @{
                ActivatedAction = ([scriptblock]::Create(
                    "Start-Process -FilePath $url
                    New-Event -SourceIdentifier 'LegoIdeas-$($p.uuid)'"
                ))
                DismissedAction = ([scriptblock]::Create(
                    "New-Event -SourceIdentifier 'LegoIdeas-$($p.uuid)'"
                ))
            }
        }
        New-BurntToastNotification @params | Out-Null
        if ($PSVersionTable.PSVersion -gt [Version]'7.1.0') {
            Wait-Event -SourceIdentifier "LegoIdeas-$($p.uuid)" | Out-Null
        }
    }
}