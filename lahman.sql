
--1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?


SELECT 
    vp.namefirst AS "First Name", 
    vp.namelast AS "Last Name",
    COALESCE(SUM(s.salary), 0) AS "Total Salary"
FROM 
    (SELECT DISTINCT p.playerid, p.namefirst, p.namelast
     FROM people p
     JOIN collegeplaying cp ON p.playerid = cp.playerid
     JOIN schools sc ON cp.schoolid = sc.schoolid
     WHERE sc.schoolname = 'Vanderbilt University') vp
LEFT JOIN salaries s ON vp.playerid = s.playerid
GROUP BY vp.playerid, vp.namefirst, vp.namelast
HAVING SUM(s.salary) IS NOT NULL
ORDER BY SUM(s.salary) DESC;

-- David Price, $81,851,296

--2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.


WITH position_groups AS (
    SELECT
        yearid,
        CASE
            WHEN pos = 'OF' THEN 'Outfield'
            WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
            WHEN pos IN ('P', 'C') THEN 'Battery'
            ELSE 'Other'
        END AS position_group,
        po
    FROM fielding
    WHERE yearid = 2016
)

SELECT position_group,
    SUM(po) AS total_putouts
FROM position_groups
WHERE position_group IN ('Outfield', 'Infield', 'Battery')
GROUP BY position_group
ORDER BY total_putouts DESC;

--3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)

WITH decades AS (
    SELECT generate_series(1920, 2020, 10) AS decade_start),
	
decade_stats AS (
    SELECT 
        d.decade_start,
        d.decade_start + 9 AS decade_end,
        ROUND(SUM(t.so)::NUMERIC / SUM(t.g)::NUMERIC, 2) AS avg_so_per_game,
        ROUND(SUM(t.hr)::NUMERIC / SUM(t.g)::NUMERIC, 2) AS avg_hr_per_game
    FROM decades d
    JOIN teams t ON t.yearid BETWEEN d.decade_start AND d.decade_start + 9
    GROUP BY d.decade_start
    ORDER BY d.decade_start
)
SELECT 
    decade_start || '-' || decade_end AS decade,
    avg_so_per_game AS "Strikeouts per Game",
    avg_hr_per_game AS "Home Runs per Game"
FROM decade_stats;


--4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.

WITH stealing_stats AS (
    SELECT
        p.playerid,
        p.namefirst,
        p.namelast,
        b.sb AS stolen_bases,
        b.cs AS caught_stealing,
        (b.sb + b.cs) AS total_attempts,
        ROUND((CAST(b.sb AS FLOAT) / (b.sb + b.cs) * 100)::numeric, 2) AS success_rate
    FROM batting b
    JOIN people p ON b.playerid = p.playerid
    WHERE b.yearid = 2016 AND (b.sb + b.cs) >= 20
)
SELECT
    namefirst AS "First Name",
    namelast AS "Last Name",
    stolen_bases AS "Stolen Bases",
    total_attempts AS "Attempts",
    success_rate AS "Success Rate"
FROM stealing_stats
ORDER BY success_rate DESC;


--5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

SELECT t.name, t.yearid, t.w
FROM teams t
WHERE t.yearid BETWEEN 1970 AND 2016 AND t.wswin = 'N'
ORDER BY t.w DESC
LIMIT 1;

SELECT t.name, t.yearid, t.w
FROM teams t
WHERE t.yearid BETWEEN 1970 AND 2016 AND t.wswin = 'Y'
ORDER BY t.w ASC;
-- There was a strike in 1981

SELECT t.name, t.yearid, t.w
FROM teams t
WHERE t.yearid BETWEEN 1970 AND 2016 AND t.yearid != 1981 AND t.wswin = 'Y'
ORDER BY t.w ASC
LIMIT 1;

WITH max_win_teams AS (
    SELECT yearid, MAX(w) as max_wins
    FROM teams
    WHERE yearid BETWEEN 1970 AND 2016 AND yearid != 1981
    GROUP BY yearid
),
winners AS (
    SELECT m.yearid
    FROM max_win_teams m
    JOIN teams t ON m.yearid = t.yearid AND m.max_wins = t.w AND t.wswin = 'Y'
)
SELECT 
    COUNT(*) AS total_matching_years,
    (COUNT(*)::FLOAT / 46 * 100)::NUMERIC(5,2) AS percentage
FROM winners;

-- A team with the most wins only wins 26.09% of the time 

--6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

WITH nl_winners AS (
    SELECT 
        am.playerid,
        am.yearid,
        t.name AS team_name
    FROM awardsmanagers am
    JOIN managers m ON am.playerid = m.playerid AND am.yearid = m.yearid
    JOIN teams t ON m.teamid = t.teamid AND m.yearid = t.yearid
    WHERE am.awardid = 'TSN Manager of the Year' AND am.lgid = 'NL'
),
al_winners AS (
    SELECT 
        am.playerid,
        am.yearid,
        t.name AS team_name
    FROM awardsmanagers am
    JOIN managers m ON am.playerid = m.playerid AND am.yearid = m.yearid
    JOIN teams t ON m.teamid = t.teamid AND m.yearid = t.yearid
    WHERE am.awardid = 'TSN Manager of the Year' AND am.lgid = 'AL'
)
SELECT 
    p.namefirst || ' ' || p.namelast AS "Manager Name",
    nl.yearid AS "NL Award Year",
    nl.team_name AS "NL Team",
    al.yearid AS "AL Award Year",
    al.team_name AS "AL Team"
FROM nl_winners nl
JOIN al_winners al ON nl.playerid = al.playerid
JOIN people p ON nl.playerid = p.playerid
ORDER BY p.namelast, p.namefirst; 


--7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.


--8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.


--9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.


--10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.







