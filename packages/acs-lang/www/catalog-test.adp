<%
    ns_set put [ns_conn outputheaders] "content-type" "text/html; charset=iso-8859-1"	
%>
@header@
<h3>@title@</h3>
<a href="/pvt/home">Your Workspace</a> : Testing the language and localization API
<hr>
<p>
[ad_locale user locale] ==> @locale@
<br>
[ad_locale user language] ==> @language@
<br>
[ad_locale_language_name @language@] ==> @language_name@
<p>


<b>Test 1</b>
<p>
<em>Verify that the message catalog loader ran
successfully at server startup.</em>
<p>
<table cellspacing=0 cellpadding=4 border=1>
<tr><th>Word to lookup</th><th>Language</th><th>Results of catalog lookup</th></tr>
<tr><td>English</td><td>English</td><td>@english@</td></tr>
<tr><td>French</td><td>French</td><td>@french@</td></tr>
<tr><td>Spanish</td><td>Spanish</td><td>@spanish@</td></tr>
<tr><td>German</td><td>German</td><td>@german@</td></tr>
</table>
<p>

<b>Test 2</b>
<p>
<em>Verify that the &lt;trn&gt; ADP tag works when the user's preferred
language is set to 
<a href="locale-set?locale=en_US">English</a>,
<a href="locale-set?locale=fr_FR">French</a>,
<a href="locale-set?locale=es_ES">Spanish</a>,
or <a href="locale-set?locale=de_DE">German</a></em>.
<p>

Test of inline &lt;TRN&gt; adp tags:
<table cellspacing=0 cellpadding=4 border=1>
<tr><th>Word to lookup</th><th>Result when user's preferred language is @language_name@</tr>
<tr><td>English</td><td><trn key="test.English">English</trn></td></tr>
<tr><td>French</td><td><trn key="test.French">French</trn></tr>
<tr><td>Spanish</td><td><trn key="test.Spanish">Spanish</trn></td></tr>
<tr><td>German</td><td><trn key="test.German">German</trn></td></td></tr>
</table>
<p>

Test of inline &lt;TRN&gt; adp tags with STATIC option:
<table cellspacing=0 cellpadding=4 border=1>
<tr><th>Word to lookup</th><th>Result when user's preferred language is @language_name@</tr>
<tr><td>English</td><td><trn static key="test.English">English</trn></td></tr>
<tr><td>French</td><td><trn static key="test.French">French</trn></tr>
<tr><td>Spanish</td><td><trn static key="test.Spanish">Spanish</trn></td></tr>
<tr><td>German</td><td><trn static key="test.German">German</trn></td></td></tr>
</table>
<p>



@footer@



