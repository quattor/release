<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:pan="http://quattor.org/pan/annotations"
                version="1.0">
  <xsl:output omit-xml-declaration="yes" encoding="iso-8859-1" indent="yes" method="xml" media-type="text/html" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
  <xsl:param name='t'/>
  <xsl:template match="pan:template">
    <html>
      <head>
        <title>Feature: <xsl:value-of select="pan:title"/></title>
        <link rel='stylesheet' href='annotations.css'/>
      </head>
      <body>
        <h1>Feature: <xsl:value-of select="pan:title"/></h1>

        <h2>Synopsis</h2>
        <xsl:apply-templates select="pan:synopsis"/>

        <h2>Description</h2>
        <xsl:value-of select="pan:desc"/>

        <xsl:if test="count(pan:function) > 0">
        <h2>Functions</h2>
        <xsl:apply-templates select="pan:function"/>
        </xsl:if>

        <xsl:if test="count(pan:variable) > 0">
        <h2>Global Variables</h2>
        <xsl:apply-templates select="pan:variable"/>
        </xsl:if>

        <xsl:if test="count(pan:see-also) > 0">
        <h2>See Also</h2>
        <ul>
        <xsl:apply-templates select="pan:see-also"/>
        </ul>
        </xsl:if>

        <h2>Template</h2>
        <blockquote class='pan'>
        <xsl:value-of select="$t"/>
        </blockquote>

      </body>
    </html>
  </xsl:template>

  <xsl:template match="pan:synopsis">
    <p>
    <xsl:value-of select="pan:synopsis"/>
    </p>
  </xsl:template>

  <xsl:template match="pan:function">
    <h3>Function <xsl:value-of select="@name"/>()</h3>
    <p>
    <xsl:value-of select="pan:desc"/>
    </p>
  </xsl:template>

  <xsl:template match="pan:variable">
    <h3>Variable <xsl:value-of select="@name"/></h3>
    <p>
    <xsl:value-of select="pan:desc"/>
    </p>
  </xsl:template>

  <xsl:template match="pan:see-also">
    <li><xsl:value-of select="."/></li>
  </xsl:template>

</xsl:stylesheet>
