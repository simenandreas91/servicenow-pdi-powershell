  removeDuplicateCollapseMarkers: function (html) {
    // Compendia can emit adjacent empty editor markers for the same section.
    // Remove only those duplicates; intervening content starts a new section.
    var source = String(html || '');
    var previousEnd = -1;
    var previousTitle = null;
    var marker = /<div\b([^>]*)>\s*<\/div>/gi;
    return source.replace(marker, function (whole, attrs, offset) {
      var classes = /\bclass\s*=\s*(["'])(.*?)\1/i.exec(attrs);
      var title = /\bdata-collapse-title\s*=\s*(["'])(.*?)\1/i.exec(attrs);
      if (!classes || !/(^|\s)collapsable(\s|$)/.test(classes[2]) || !title) return whole;
      var duplicate = previousTitle === title[2] && previousEnd >= 0 &&
        /^\s*$/.test(source.substring(previousEnd, offset));
      previousTitle = title[2];
      previousEnd = offset + whole.length;
      return duplicate ? '' : whole;
    });
  },

