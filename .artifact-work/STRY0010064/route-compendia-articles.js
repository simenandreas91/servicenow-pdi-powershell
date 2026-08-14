(function executeFix() {
  var MAX_ARTICLES = 500;
  var targets = {
    'leadership-portal': {
      knowledgeBaseTitle: 'Compendia - Leadership Portal',
      categoryLabel: 'Leadership Portal'
    },
    'personal-offshore': {
      knowledgeBaseTitle: 'Compendia - Offshore',
      categoryLabel: 'Personal Offshore'
    }
  };

  function getActiveKnowledgeBase(title) {
    var grKnowledgeBase = new GlideRecord('kb_knowledge_base');
    grKnowledgeBase.addQuery('title', title);
    grKnowledgeBase.addQuery('active', true);
    grKnowledgeBase.setLimit(2);
    grKnowledgeBase.query();
    if (!grKnowledgeBase.next()) {
      throw 'Active knowledge base not found: ' + title;
    }
    var sysId = grKnowledgeBase.getUniqueValue();
    if (grKnowledgeBase.next()) {
      throw 'Multiple active knowledge bases found with title: ' + title;
    }
    return sysId;
  }

  function getCategory(knowledgeBaseSysId, label) {
    var grCategory = new GlideRecord('kb_category');
    grCategory.addQuery('parent_id', knowledgeBaseSysId);
    grCategory.addQuery('label', label);
    grCategory.setLimit(2);
    grCategory.query();
    if (!grCategory.next()) {
      throw 'Category not found under target knowledge base: ' + label;
    }
    var sysId = grCategory.getUniqueValue();
    if (grCategory.next()) {
      throw 'Multiple target categories found: ' + label;
    }
    return sysId;
  }

  var resolvedTargets = {};
  for (var slug in targets) {
    if (!targets.hasOwnProperty(slug)) {
      continue;
    }
    var targetKnowledgeBase = getActiveKnowledgeBase(targets[slug].knowledgeBaseTitle);
    resolvedTargets[slug] = {
      knowledgeBase: targetKnowledgeBase,
      category: getCategory(targetKnowledgeBase, targets[slug].categoryLabel)
    };
  }

  var encodedQuery = 'u_compendia_page_idSTARTSWITHleadership-portal:^ORu_compendia_page_idSTARTSWITHpersonal-offshore:';
  var grCount = new GlideAggregate('kb_knowledge');
  grCount.addEncodedQuery(encodedQuery);
  grCount.addAggregate('COUNT');
  grCount.query();
  grCount.next();
  var matched = parseInt(grCount.getAggregate('COUNT'), 10) || 0;
  if (matched > MAX_ARTICLES) {
    throw 'Safety limit exceeded. Matched ' + matched + ' articles; maximum is ' + MAX_ARTICLES + '.';
  }

  var changed = 0;
  var unchanged = 0;
  var errors = 0;
  var grArticle = new GlideRecord('kb_knowledge');
  grArticle.addEncodedQuery(encodedQuery);
  grArticle.orderBy('sys_id');
  grArticle.setLimit(MAX_ARTICLES);
  grArticle.query();
  while (grArticle.next()) {
    try {
      var pageId = grArticle.getValue('u_compendia_page_id') || '';
      var articleSlug = pageId.split(':')[0];
      var target = resolvedTargets[articleSlug];
      if (!target) {
        errors++;
        gs.error('[STRY0010064] Unsupported Compendia page identifier on article ' + grArticle.getValue('number') + ': ' + pageId);
        continue;
      }
      if (grArticle.getValue('kb_knowledge_base') === target.knowledgeBase &&
          grArticle.getValue('kb_category') === target.category) {
        unchanged++;
        continue;
      }
      grArticle.setValue('kb_knowledge_base', target.knowledgeBase);
      grArticle.setValue('kb_category', target.category);
      grArticle.update();
      changed++;
    } catch (articleError) {
      errors++;
      gs.error('[STRY0010064] Failed to route article ' + grArticle.getValue('number') + ': ' + articleError);
    }
  }

  gs.info('[STRY0010064] Compendia article routing complete. matched=' + matched + ', changed=' + changed + ', unchanged=' + unchanged + ', errors=' + errors + '.');
})();
