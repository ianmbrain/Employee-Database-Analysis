
-- Fetch each employee's name and title
SELECT e.first_name AS first_name, e.last_name AS last_name, t.title AS title
FROM employee.employees e
JOIN employee.titles t 
	ON e.emp_no = t.emp_no
	
-- Fetch each departments average salary 
WITH dep_salaries AS (
	SELECT s.emp_no AS emp_no, s.salary AS salary, deps.dept_no AS dept_no, deps.dept_name AS dept_name
	FROM Employee.salaries s 
	JOIN (
		SELECT de.emp_no AS emp_no, de.dept_no AS dept_no, d.dept_name AS dept_name
		FROM employee.dept_emp de
		LEFT JOIN employee.departments d
			ON de.dept_no = d.dept_no
		ORDER BY dept_no) deps
		ON s.emp_no = deps.emp_no)
SELECT dept_name, dept_no, ROUND(AVG(salary),2) AS avg_salary
FROM dep_salaries 
GROUP BY dept_name, dept_no
ORDER BY avg_salary DESC
-- Here I join dept_emp with departments to get the department name and number together. I then join that with salaries to get
-- the salary with emp_no and department name. I then query the AVG(salary) from this CTE

-- Fetch the average salary each year
SELECT DATE_FORMAT(from_date, "%Y") AS 'year', AVG(salary) AS avg_salary
FROM employee.salaries
GROUP BY DATE_FORMAT(from_date, "%Y")
ORDER BY DATE_FORMAT(from_date, "%Y")

-- Fetch the beginning and current salary for each employee.
SELECT *
FROM (
	SELECT x.emp_no AS emp_no, x.salary AS beginning_salary
	FROM (
		SELECT *, RANK() OVER(PARTITION BY emp_no ORDER BY from_date) AS rnk
		FROM employee.salaries) x
	WHERE x.rnk = 1) a
JOIN (
	SELECT x.emp_no AS emp_no, x.salary AS current_salary
	FROM (
		SELECT *, RANK() OVER(PARTITION BY emp_no ORDER BY from_date DESC) AS rnk
		FROM employee.salaries) x
	WHERE x.rnk = 1) b
	ON a.emp_no = b.emp_no
-- Each employee's from_dates are ranked in either ASC or DESC order. The first and last from_date for each employee 
	-- is then returned thus returning the first and last salary

-- Fetch the avg employee salary (not including manager salary) and manager salary for each department
WITH managers AS (
	SELECT m.dept_no AS dept_no, m.emp_no AS emp_no, d.dept_name AS dept_name
	FROM employee.dept_manager m
	LEFT JOIN employee.departments d
		ON m.dept_no = d.dept_no
	WHERE m.to_date = '9999-01-01'),
-- This subquery returns a managers emp_no, dept_no, and dept_name
dep_mngr_salary AS(
	SELECT m.dept_no, ROUND(AVG(s.salary),2) AS avg_mngr_salary
	FROM managers m
	JOIN employee.salaries s
		ON m.emp_no = s.emp_no 
	WHERE s.to_date = '9999-01-01'
	GROUP BY m.dept_no 
	ORDER BY m.dept_no),
-- This returns the average manager_salary by department
dep_emp_salary AS (
	SELECT e.dept_no, avg(s.salary) AS avg_emp_salary
	FROM employee.salaries s
	JOIN employee.dept_emp e
		ON s.emp_no = e.emp_no
	WHERE s.emp_no NOT IN (SELECT emp_no FROM employee.dept_manager ) AND s.to_date = '9999-01-01'
	GROUP BY e.dept_no
	ORDER BY e.dept_no)
SELECT *, ROUND(((avg_mngr_salary - avg_emp_salary) / avg_emp_salary) * 100, 2) AS difference
FROM dep_emp_salary e
JOIN dep_mngr_salary m
	ON e.dept_no = m.dept_no

-- Fetch the highest salary in each department
SELECT b.dept_name, a.max_salary
FROM (
	SELECT dept_no, MAX(s.salary) AS max_salary
	FROM salaries s
	JOIN dept_emp d 
		ON s.emp_no = d.emp_no 
	GROUP BY d.dept_no) a
JOIN (
	SELECT *
	FROM departments) b
	ON a.dept_no = b.dept_no
ORDER BY a.max_salary DESC
-- The salaries and dept_emp table are combined to return the MAX(salary) by department
	-- The departments table is then joined to add the respective departments name

-- Fetch each employee and their respective manager for the current period. Group employees by their department
SELECT DISTINCT e.emp_no AS emp_no, m.emp_no AS mngr_no, m.to_date AS cur_date, e.dept_no AS dept_no
FROM dept_emp e 
LEFT JOIN dept_manager m
	ON e.dept_no = m.dept_no
WHERE m.to_date IN (SELECT MAX(to_date) FROM dept_manager GROUP BY dept_no)
ORDER BY dept_no
-- IN... is used to select managers who are currently managing a department

-- Fetch the most recently hired employee in each department
SELECT x.emp_no, x.dept_no, x.hire_date
FROM 
	(SELECT emp_no, dept_no, from_date AS hire_date, RANK() OVER(PARTITION BY dept_no ORDER BY from_date DESC) AS rnk
	FROM dept_emp) x
WHERE x.rnk = 1
-- Since an employees from_date = hire_date we do not need to JOIN the employees and dept_emp tables

-- Label employees based on if their current salary more than $100,000 each year  
SELECT emp_no, salary,
	CASE 
		WHEN salary >= 100000 THEN 'Highly Paid'
		ELSE 'Regular Salary'
	END AS salary_type
FROM salaries
WHERE to_date = '9999-01-01'
-- The case statement is used to create a new column where employees are either "Highly Paid" or "Regular"

-- Create a temporary table for employees and their respective manager
CREATE TEMPORARY TABLE temp_emp_mngr (emp_no INT, mngr_no INT, cur_date date, dept_no VARCHAR(10));

-- Inserting data into the temporary table
INSERT INTO temp_emp_mngr
	SELECT DISTINCT e.emp_no AS emp_no, m.emp_no AS mngr_no, m.to_date AS cur_date, e.dept_no AS dept_no
	FROM dept_emp e 
	LEFT JOIN dept_manager m
		ON e.dept_no = m.dept_no
	WHERE m.to_date IN (SELECT MAX(to_date) FROM dept_manager GROUP BY dept_no)
	ORDER BY dept_no
	
-- Fetch the average salary for each department every year. Make dept_no a header for each department
WITH dept_sal AS (
	SELECT e.emp_no, e.dept_no, s.salary, DATE_FORMAT(s.to_date, "%Y") AS 'year_end'
	FROM employee.salaries s
	JOIN employee.dept_emp e 
		ON s.emp_no = e.emp_no)
SELECT year_end,
	MAX(CASE WHEN dept_no = 'd001' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd001',
	MAX(CASE WHEN dept_no = 'd002' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd002',
	MAX(CASE WHEN dept_no = 'd003' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd003',
	MAX(CASE WHEN dept_no = 'd004' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd004',
	MAX(CASE WHEN dept_no = 'd005' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd005',
	MAX(CASE WHEN dept_no = 'd006' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd006',
	MAX(CASE WHEN dept_no = 'd007' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd007',
	MAX(CASE WHEN dept_no = 'd008' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd008',
	MAX(CASE WHEN dept_no = 'd009' THEN ROUND(avg_sal,0) ELSE '' END) AS 'd009'
FROM (
	SELECT dept_no, year_end, AVG(salary) AS avg_sal
	FROM dept_sal
	GROUP BY dept_no, year_end
	ORDER BY dept_no, year_end) x
GROUP BY year_end
-- Each employee's number, salary, years, and department_no is fetched.	
	-- The average salary is then grouped by the department and year to find the average for each department every year
	-- Case is used to create a new column for each dept_no so the resulting query is easier to read

-- Fetch the same information as the above table. Use Dynamic SQL to achieve this query
CREATE TEMPORARY TABLE annual_salaries
WITH dept_sal AS (
	SELECT e.emp_no, e.dept_no, s.salary, DATE_FORMAT(s.to_date, "%Y") AS 'year_end'
	FROM employee.salaries s
	JOIN employee.dept_emp e 
		ON s.emp_no = e.emp_no)
SELECT dept_no, year_end, ROUND(AVG(salary),0) AS avg_sal
FROM dept_sal
GROUP BY dept_no, year_end
ORDER BY dept_no, year_end

SET @sql = NULL;
SELECT GROUP_CONCAT(
	DISTINCT CONCAT(
		'ifnull(SUM(case when dept_no = ''',
      	dept_no,
      	''' then ROUND(avg_sal,0) end),0) AS `',
      	dept_no, '`')) 
    INTO @sql
FROM annual_salaries;
SET @sql = CONCAT(
	'SELECT year_end, ', @sql,
	' FROM annual_salaries 
	GROUP BY year_end');
PREPARE stmt1 FROM @sql;
EXECUTE stmt1;

-- Fetch employees whose current job title is different than the title they were hired for
WITH emp_dates AS (
	SELECT emp_no, MIN(from_date) OVER(PARTITION BY emp_no) AS beg_date, MAX(to_date) OVER(PARTITION BY emp_no) AS end_date
	FROM titles),
first_title AS (
	SELECT DISTINCT(d.emp_no), d.beg_date, d.end_date, t.title
	FROM emp_dates d
	JOIN titles t
		ON d.emp_no = t.emp_no AND d.beg_date = t.from_date),
cur_title AS (
	SELECT DISTINCT(d.emp_no), d.beg_date, d.end_date, t.title
	FROM emp_dates d
	JOIN titles t
		ON d.emp_no = t.emp_no AND d.end_date = t.to_date)
SELECT f.emp_no, f.title AS beg_title, c.title AS end_title
FROM first_title f
JOIN cur_title c
	ON f.emp_no = c.emp_no
WHERE f.title <> c.title

-- stored procedure, dynamic SQL 
	



