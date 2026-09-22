<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes"/>

    <!-- Define template to extract parent dir of test file  using xslt 1.0 -->
    <xsl:template name="get-parent-folder">
        <xsl:param name="path"/>
        <xsl:param name="previous"/>
        <xsl:choose>
            <xsl:when test="contains($path, '/')">
                <xsl:call-template name="get-parent-folder">
                    <xsl:with-param name="path" select="substring-after($path, '/')"/>
                    <xsl:with-param name="previous" select="substring-before($path, '/')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$previous"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!---->

    <!-- Template for checking if given needle is contained inside haystack (it ignores case sensitivity) -->
    <xsl:template name="contains-ignore-case">
        <xsl:param name="haystack"/>
        <xsl:param name="needle"/>

        <xsl:variable name="lower-haystack"
            select="translate($haystack, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/>
        <xsl:variable name="lower-needle"
            select="translate($needle, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/>

        <xsl:choose>
            <xsl:when test="contains($lower-haystack, $lower-needle)">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Reusable template for rendering a Log Action row -->
    <xsl:template name="render-log-action-row">
      <xsl:param name="actionType"/>

      <tr>
        <td><xsl:value-of select="./status/@start"/></td>
        <td><xsl:value-of select="$actionType"/></td>
        <td><xsl:value-of select="./kw[@name='Log']/msg"/></td>

        <!-- Validate if verify word is present in action description and assign result string into variable-->
        <xsl:variable name="isVerify">
            <xsl:call-template name="contains-ignore-case">
                <xsl:with-param name="haystack" select="./kw[@name='Log']/msg"/>
                <xsl:with-param name="needle" select="'verify'"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:choose>
            <!-- use previously validation of verify word here -->
            <xsl:when test="$isVerify = 'true'">
                <td>
                    <span class="{./status/@status}">
                        <xsl:value-of select="./status/@status"/>
                    </span>
                </td>
            </xsl:when>
            <xsl:otherwise>
              <td>N/A</td>
            </xsl:otherwise>
        </xsl:choose>
      </tr>
    </xsl:template>

    <xsl:template match="/">
        <html>
            <head>
                <title>Robot Framework Report</title>
                <style>
                    html, body {
                      font-family: Arial, sans-serif;
                      margin: 0;
                      padding: 0;
                    }

                    .center-container {
                      display: flex;
                      flex-direction: column;
                      align-items: center;
                      width: min(90%, 1200px); /* Responsive max width */
                      margin: 0 auto;
                    }

                    hr {
                      width: 100%;
                      border: none;
                      height: 2px;
                      background-color: #333;
                      margin: 10px 0;
                    }

                    .pass { color: green; }
                    .fail { color: red; }

                    .suite_script_log,
                    .test_script_log {
                      border-spacing: 15px;
                      text-align: left;
                      width: 95%;
                    }

                    .test_script_log th,
                    .suite_script_log th {
                      text-align: center;
                    }

                    .report_info_container,
                    .log_header,
                    .log_footer {
                      width: 100%;
                    }

                    .log_header_text,
                    .log_footer_text {
                      text-align: left;
                      width: 100%;
                    }
                </style>
            </head>
            <body>
                <div class="center-container">
                    <div class="report_info_container">
                        <h3>Test Report Name:</h3>
                        <p>Placeholder for report name</p>
                        <hr/>
                    </div>

                    <!-- Render Suite Setup Steps only when .xml file contains it -->
                    <xsl:if test="/robot/suite/kw">
                            <table class="suite_script_log">
                                <tr>
                                    <th>Timestamp</th>
                                    <th>Action Type</th>
                                    <th>Action Description</th>
                                    <th colspan="2">Action</th>
                                    <th>Result</th>
                                </tr>

                                <!-- Handle SETUP steps -->
                                <!-- Handle nested Log Action steps inside other SETUP kw elements -->
                                <xsl:for-each select="/robot//suite/kw[@type='SETUP' and @name!='Log Action']">
                                    <xsl:for-each select="kw[@name='Log Action']">
                                        <xsl:call-template name="render-log-action-row">
                                            <xsl:with-param name="actionType" select="'Suite Setup Step'"/>
                                        </xsl:call-template>
                                    </xsl:for-each>
                                </xsl:for-each>

                                <!-- Handle direct SETUP Log Action steps -->
                                <xsl:for-each select="/robot//suite/kw[@type='SETUP' and @name='Log Action']">
                                    <xsl:call-template name="render-log-action-row">
                                        <xsl:with-param name="actionType" select="'Suite Setup Step'"/>
                                    </xsl:call-template>
                                </xsl:for-each>

                                <!-- Handle TEARDOWN steps -->
                                <!-- Handle nested Log Action steps inside other TEARDOWN kw elements -->
                                <xsl:for-each select="/robot//suite/kw[@type='TEARDOWN' and @name!='Log Action']">
                                    <xsl:for-each select="kw[@name='Log Action']">
                                        <xsl:call-template name="render-log-action-row">
                                            <xsl:with-param name="actionType" select="'Suite Teardown Step'"/>
                                        </xsl:call-template>
                                    </xsl:for-each>
                                </xsl:for-each>

                                <!-- Handle direct TEARDOWN Log Action steps -->
                                <xsl:for-each select="/robot//suite/kw[@type='TEARDOWN' and @name='Log Action']">
                                    <xsl:call-template name="render-log-action-row">
                                        <xsl:with-param name="actionType" select="'Suite Teardown Step'"/>
                                    </xsl:call-template>
                                </xsl:for-each>

                            </table>
                            <hr/>
                    </xsl:if>
                </div>
                <xsl:for-each select="robot//suite/test">
                    <div class="center-container">
                        <div class="log_header">
                            <div class="log_header_text">
                                <p>Tester Name:
                                    <xsl:value-of select="/robot/@tester"/>
                                </p>
                                <p>Test folder:
                                    <!-- Call the template which will fetch parent directory of file -->
                                    <!-- First make sure to normalize path to one type of separator -->
                                    <xsl:variable name="normalizedPath"
                                                  select="translate(/robot//suite/@source, '\', '/')"/>
                                    <xsl:call-template name="get-parent-folder">
                                        <xsl:with-param name="path" select="$normalizedPath"/>
                                        <xsl:with-param name="previous" select="''"/>
                                    </xsl:call-template>
                                </p>
                                <p>Test Case Name:
                                    <xsl:value-of select="@name"/>
                                </p>
                                <p>Test Case ID:
                                    <xsl:value-of select="substring-before(@name, ':')"/>
                                </p>
                                <p>Date:
                                    <xsl:value-of select="status/@start"/>
                                </p>
                            </div>
                        </div>
                        <hr/>
                        <table class="test_script_log">
                            <tr>
                                <th>Timestamp</th>
                                <th>Action Type</th>
                                <th>Action Description</th>
                                <th>Result</th>
                            </tr>

                            <!-- Handle SETUP steps -->
                            <!-- Handle nested Log Action steps inside other SETUP kw elements -->
                            <xsl:for-each select="kw[@type='SETUP' and @name!='Log Action']">
                                <xsl:for-each select="kw[@name='Log Action']">
                                    <xsl:call-template name="render-log-action-row">
                                        <xsl:with-param name="actionType" select="'Test Setup Step'"/>
                                    </xsl:call-template>
                                </xsl:for-each>
                            </xsl:for-each>

                            <!-- Handle direct SETUP Log Action steps -->
                            <xsl:for-each select="kw[@type='SETUP' and @name='Log Action']">
                                <xsl:call-template name="render-log-action-row">
                                    <xsl:with-param name="actionType" select="'Test Setup Step'"/>
                                </xsl:call-template>
                            </xsl:for-each>

                            <!-- Handle TEST STEPS named Log Action -->
                            <xsl:for-each select=".//kw[@name='Log Action' and not(@type) and (parent::kw[not(@type)] or parent::test)]">
                                <xsl:call-template name="render-log-action-row">
                                    <xsl:with-param name="actionType" select="'Test Step'"/>
                                </xsl:call-template>
                            </xsl:for-each>

                            <!-- Handle TEARDOWN steps -->
                            <!-- Handle nested Log Action steps inside other TEARDOWN kw elements -->
                            <xsl:for-each select="kw[@type='TEARDOWN' and @name!='Log Action']">
                                <xsl:for-each select="kw[@name='Log Action']">
                                    <xsl:call-template name="render-log-action-row">
                                        <xsl:with-param name="actionType" select="'Test Teardown Step'"/>
                                    </xsl:call-template>
                                </xsl:for-each>
                            </xsl:for-each>

                            <!-- Handle direct TEARDOWN Log Action steps -->
                            <xsl:for-each select="kw[@type='TEARDOWN' and @name='Log Action']">
                                <xsl:call-template name="render-log-action-row">
                                    <xsl:with-param name="actionType" select="'Test Teardown Step'"/>
                                </xsl:call-template>
                            </xsl:for-each>
                        </table>
                        <hr/>
                        <div class="log_footer">
                            <div class="log_footer_text">
                                <p>Test Case Verdict:
                                    <span class="{status/@status}">
                                        <xsl:value-of select="status/@status"/>
                                    </span>
                                </p>
                                <p>Duration:
                                    <xsl:value-of select="status/@elapsed"/>
                                </p>
                            </div>
                            <hr/>
                        </div>
                    </div>
                </xsl:for-each>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>