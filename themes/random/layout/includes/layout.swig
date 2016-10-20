{% include 'head.swig' %}
<body>
{% include 'side-pagination.swig' %}
<div id="outer-container" class="hide-area">
<div id="container">
  <div id="menu-outer" class="slide-down">
    <div id="menu-inner">
      <div id="brand">
        {# <a href="{{ url_for('/') }}"> #}
        <a onClick="openUserCard()">
          <img id="avatar" src="{{theme.avatar}}"/>
          <div id="homelink">{{config.title}}</div>
        </a>
      </div>
      <div id="menu-list">
        <ul>
        {% set menu = config.menu || theme.menu %}
        {% for key in Object.keys(menu) %}
          {% if is_current(menu[key]) %}
            <li class="active">
          {% else %}
            <li>
          {% endif %}
            <a href="{{ url_for(menu[key]) }}">{{ key }}</a>
            {# <span>{{key}}</span> #}
          </li>
        {% endfor %}
        </ul>
      </div>
      <div id="animation-menu">
        <svg viewBox="0 0 800 600">
          <path d="M300,220 C300,220 520,220 540,220 C740,220 640,540 520,420 C440,340 300,200 300,200" id="top"></path>
          <path d="M300,320 L540,320" id="middle"></path>
          <path d="M300,210 C300,210 520,210 540,210 C740,210 640,530 520,410 C440,330 300,190 300,190" id="bottom" transform="translate(480, 320) scale(1, -1) translate(-480, -318) "></path>
        </svg>
      </div>
      <!--<div id="show-menu">
        <button>菜单</button>
      </div> -->
    </div>
  </div>

  <div id="content-outer">
    <div id="content-inner">
      {# {% autoescape false %}{{ body }}{% endautoescape %} #}
      {% block body %}{% endblock %}
      {% if page.comments && (theme.duoshuo_shortname || config.duoshuo_shortname) %}
      <div class="ds-thread" data-thread-key="{{ page.path }}" data-title="{{ page.title }}" data-url="{{ page.permalink }}"></div>
      {% endif %}
      {% if page.comments && (config.uyan_id || theme.uyan_id) %}
      <div id="uyan_frame"></div>
      {% endif %}
      {% if page.comments && (config.disqus_shortname || theme.disqus_shortname) %}
      <div id="disqus_thread"></div>
      {% endif %}
    </div>
  </div>

  <div id="bottom-outer">
    <div id="bottom-inner">
      ©2016,Site by <a href="http://weibo.com/kongkongss">WenJunHuang</a> using Hexo
      <br>
      {% if config.since %}
        &copy;
        {% set thisYear = date(Date.now(), 'YYYY') %}

        {{config.since}}
        {% if thisYear != config.since %}
         - {{ date(Date.now(), 'YYYY') }}
        {% endif %}
      {% endif %}
    </div>
  </div>
</div>

</div>
{% if page.comments && (theme.duoshuo_shortname || config.duoshuo_shortname) %}
  {% include 'duoshuo.swig' %}
{% endif %}
{% if page.comments && (config.disqus_shortname || theme.disqus_shortname) %}
  {% include 'disqus.swig' %}
{% endif %}
{% if page.comments && (config.uyan_id || theme.uyan_id) %}
  {% include 'uyan.swig' %}
{% endif %}
{% include 'footer.swig' %}
